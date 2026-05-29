from io import BytesIO
import audioop
import shutil
import uuid
import wave
from pathlib import Path

import speech_recognition as sr
from deep_translator import GoogleTranslator
from fastapi import BackgroundTasks, FastAPI, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from moviepy import VideoFileClip
from pydantic import BaseModel
import yt_dlp
import asyncio
import json
import csv
import threading
import nltk
from nltk.corpus import wordnet as wn
from nltk.stem import WordNetLemmatizer
import requests
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import cv2
import mediapipe as mp
import base64
import numpy as np

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
hands_detector = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)
mp_drawing = mp.solutions.drawing_utils

PEXELS_KEY = "1MAZ1kwZKpAhXlvkq37iL5ObycViTqgdw7R4k2I1jCK9Ugjjnm3hL2hi"

def load_phrases_mapping():
    phrase_mapping = {}
    try:
        csv_path = Path(__file__).resolve().parent / "components" / "handgesture" / "ISL_All_86_Phrases.csv"
        with open(csv_path, 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file)
            next(csv_reader, None)
            for row in csv_reader:
                if len(row) >= 2:
                    phrases_text = row[0]
                    video_file = row[1]
                    phrases = [p.strip() for p in phrases_text.split('/')]
                    for phrase in phrases:
                        phrase_mapping[phrase.lower()] = video_file
    except Exception as e:
        print(f"Error loading CSV: {e}")
    return phrase_mapping

PHRASE_MAPPING = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    def download_nltk():
        nltk.download('wordnet', quiet=True)
        nltk.download('omw-1.4', quiet=True)
    threading.Thread(target=download_nltk).start()
    
    global PHRASE_MAPPING
    PHRASE_MAPPING = load_phrases_mapping()
    yield

app = FastAPI(title="Captrio Speech Translation API", lifespan=lifespan)
gif_folder = Path(__file__).resolve().parent / "components" / "handgesture" / "gif"
app.mount("/gifs", StaticFiles(directory=str(gif_folder)), name="gifs")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

recognizer = sr.Recognizer()

LANGUAGE_MAP = {
    "english": {"speech": "en-IN", "translate": "en"},
    "hindi": {"speech": "hi-IN", "translate": "hi"},
    "tamil": {"speech": "ta-IN", "translate": "ta"},
    "telugu": {"speech": "te-IN", "translate": "te"},
    "malayalam": {"speech": "ml-IN", "translate": "ml"},
}

BASE_DIR = Path(__file__).resolve().parent
UPLOADS_DIR = BASE_DIR / "uploads"
AUDIO_DIR = BASE_DIR / "audio"
YOUTUBE_DIR = BASE_DIR / "youtube"

UPLOADS_DIR.mkdir(exist_ok=True)
AUDIO_DIR.mkdir(exist_ok=True)
YOUTUBE_DIR.mkdir(exist_ok=True)

jobs = {}


class YoutubeRequest(BaseModel):
    url: str
    target_language: str


def convert_wav_to_audio_data(audio_bytes: bytes) -> sr.AudioData:
    try:
        with wave.open(BytesIO(audio_bytes), "rb") as wav_file:
            sample_rate = wav_file.getframerate()
            sample_width = wav_file.getsampwidth()
            frames = wav_file.readframes(wav_file.getnframes())

            if wav_file.getnchannels() == 2:
                frames = audioop.tomono(frames, sample_width, 1, 1)

            return sr.AudioData(frames, sample_rate, sample_width)
    except wave.Error:
        raise ValueError("Unsupported audio format. Send PCM WAV audio only.")


def translate_text(source_text: str, source_key: str, target_key: str) -> str:
    if source_key == target_key:
        return source_text

    return GoogleTranslator(
        source=LANGUAGE_MAP[source_key]["translate"],
        target=LANGUAGE_MAP[target_key]["translate"],
    ).translate(source_text)


def recognize_chunk(audio_data: sr.AudioData, source_key: str) -> str:
    return recognizer.recognize_google(
        audio_data,
        language=LANGUAGE_MAP[source_key]["speech"],
    ).strip()


def extract_audio_from_video(video_path: Path, output_wav_path: Path):
    clip = VideoFileClip(str(video_path))
    try:
        if clip.audio is None:
            raise ValueError("Uploaded video has no audio track.")

        clip.audio.write_audiofile(
            str(output_wav_path),
            fps=16000,
            nbytes=2,
            codec="pcm_s16le",
            ffmpeg_params=["-ac", "1"],
            logger=None,
        )
    finally:
        clip.close()


def init_job(session_id: str, target_language: str):
    jobs[session_id] = {
        "success": True,
        "session_id": session_id,
        "status": "buffering",
        "target_language": target_language,
        "captions": [],
        "error": "",
    }


def set_job_status(session_id: str, status: str):
    if session_id in jobs:
        jobs[session_id]["status"] = status


def append_caption(session_id: str, caption: dict):
    if session_id in jobs:
        jobs[session_id]["captions"].append(caption)


def complete_job(session_id: str):
    if session_id in jobs:
        jobs[session_id]["status"] = "ready"


def fail_job(session_id: str, error: str):
    if session_id in jobs:
        jobs[session_id]["status"] = "failed"
        jobs[session_id]["error"] = error


def stream_wav_chunks_to_job(
    session_id: str,
    audio_bytes: bytes,
    source_key: str,
    target_key: str,
):
    with wave.open(BytesIO(audio_bytes), "rb") as wav_file:
        sample_rate = wav_file.getframerate()
        sample_width = wav_file.getsampwidth()
        channels = wav_file.getnchannels()
        total_frames = wav_file.getnframes()
        frames = wav_file.readframes(total_frames)

    if channels == 2:
        frames = audioop.tomono(frames, sample_width, 1, 1)
        channels = 1

    bytes_per_second = sample_rate * sample_width * channels
    chunk_seconds = 4
    chunk_size = bytes_per_second * chunk_seconds

    total_length = len(frames)
    index = 0
    start_time = 0.0

    set_job_status(session_id, "processing")

    while index < total_length:
        chunk_frames = frames[index:index + chunk_size]
        duration_seconds = len(chunk_frames) / bytes_per_second

        if not chunk_frames:
            break

        audio_data = sr.AudioData(chunk_frames, sample_rate, sample_width)

        try:
            source_text = recognize_chunk(audio_data, source_key)

            if source_text:
                translated_text = translate_text(source_text, source_key, target_key)
                append_caption(session_id, {
                    "start": round(start_time, 2),
                    "end": round(start_time + duration_seconds, 2),
                    "source_text": source_text,
                    "translated_text": translated_text.strip() if translated_text else "",
                })
        except sr.UnknownValueError:
            pass
        except sr.RequestError:
            pass
        except Exception:
            pass

        start_time += duration_seconds
        index += chunk_size

    complete_job(session_id)


def process_uploaded_media_job(
    session_id: str,
    file_path: str,
    media_type: str,
    target_language: str,
):
    try:
        target_key = target_language.strip().lower()
        if target_key not in LANGUAGE_MAP:
            target_key = "english"

        source_key = "english"
        path = Path(file_path)

        if media_type == "video":
            wav_path = AUDIO_DIR / f"{session_id}.wav"
            extract_audio_from_video(path, wav_path)
            with open(wav_path, "rb") as f:
                audio_bytes = f.read()
        else:
            if path.suffix.lower() != ".wav":
                raise ValueError("For now, uploaded audio must be WAV.")
            with open(path, "rb") as f:
                audio_bytes = f.read()

        stream_wav_chunks_to_job(
            session_id=session_id,
            audio_bytes=audio_bytes,
            source_key=source_key,
            target_key=target_key,
        )
    except Exception as e:
        fail_job(session_id, str(e))


def download_youtube_audio_to_wav(session_id: str, url: str) -> Path:
    wav_path = AUDIO_DIR / f"{session_id}.wav"
    output_template = str(YOUTUBE_DIR / f"{session_id}.%(ext)s")

    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "noplaylist": True,
        "quiet": True,
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "wav",
            }
        ],
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    produced_wav = YOUTUBE_DIR / f"{session_id}.wav"
    if not produced_wav.exists():
        raise ValueError("Unable to prepare YouTube audio as WAV.")

    shutil.copy(produced_wav, wav_path)
    return wav_path


def process_youtube_job(session_id: str, url: str, target_language: str):
    try:
        target_key = target_language.strip().lower()
        if target_key not in LANGUAGE_MAP:
            target_key = "english"

        source_key = "english"

        wav_path = download_youtube_audio_to_wav(session_id, url)

        with open(wav_path, "rb") as f:
            audio_bytes = f.read()

        stream_wav_chunks_to_job(
            session_id=session_id,
            audio_bytes=audio_bytes,
            source_key=source_key,
            target_key=target_key,
        )
    except Exception as e:
        fail_job(session_id, str(e))


@app.get("/")
def root():
    return {
        "success": True,
        "message": "Captrio backend running"
    }


@app.get("/health")
def health():
    return {
        "success": True,
        "service": "speech-recognition + deep-translator + live upload jobs"
    }


@app.get("/languages")
def get_languages():
    return {
        "success": True,
        "languages": [
            {
                "label": key.title(),
                "speech_code": value["speech"],
                "translate_code": value["translate"],
            }
            for key, value in LANGUAGE_MAP.items()
        ],
    }


@app.post("/translate-audio")
async def translate_audio(
    audio: UploadFile = File(...),
    source_language: str = Form(...),
    target_language: str = Form(...),
):
    source_key = source_language.strip().lower()
    target_key = target_language.strip().lower()

    if source_key not in LANGUAGE_MAP:
        return {
            "success": False,
            "error": "Unsupported source language",
            "source_text": "",
            "translated_text": "",
        }

    if target_key not in LANGUAGE_MAP:
        return {
            "success": False,
            "error": "Unsupported target language",
            "source_text": "",
            "translated_text": "",
        }

    try:
        audio_bytes = await audio.read()

        if not audio_bytes:
            return {
                "success": False,
                "error": "Empty audio file received",
                "source_text": "",
                "translated_text": "",
            }

        audio_data = convert_wav_to_audio_data(audio_bytes)

        source_text = recognizer.recognize_google(
            audio_data,
            language=LANGUAGE_MAP[source_key]["speech"],
        ).strip()

        if not source_text:
            return {
                "success": False,
                "error": "No speech detected",
                "source_text": "",
                "translated_text": "",
            }

        translated_text = translate_text(source_text, source_key, target_key)

        return {
            "success": True,
            "source_language": source_key,
            "target_language": target_key,
            "source_text": source_text,
            "translated_text": translated_text.strip() if translated_text else "",
        }

    except sr.UnknownValueError:
        return {
            "success": False,
            "error": "Speech not recognized",
            "source_text": "",
            "translated_text": "",
        }
    except sr.RequestError:
        return {
            "success": False,
            "error": "Speech recognition service unavailable",
            "source_text": "",
            "translated_text": "",
        }
    except ValueError as e:
        return {
            "success": False,
            "error": str(e),
            "source_text": "",
            "translated_text": "",
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Internal server error: {str(e)}",
            "source_text": "",
            "translated_text": "",
        }


@app.post("/upload-media")
async def upload_media(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    media_type: str = Form(...),
    target_language: str = Form(...),
):
    try:
        session_id = str(uuid.uuid4())
        ext = Path(file.filename).suffix or (".wav" if media_type == "audio" else ".mp4")
        save_path = UPLOADS_DIR / f"{session_id}{ext}"

        with open(save_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        init_job(session_id, target_language)

        background_tasks.add_task(
            process_uploaded_media_job,
            session_id,
            str(save_path),
            media_type,
            target_language,
        )

        return {
            "success": True,
            "session_id": session_id,
            "status": "buffering",
            "file_name": file.filename,
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


@app.post("/upload-youtube")
async def upload_youtube(
    payload: YoutubeRequest,
    background_tasks: BackgroundTasks,
):
    try:
        session_id = str(uuid.uuid4())
        init_job(session_id, payload.target_language)

        background_tasks.add_task(
            process_youtube_job,
            session_id,
            payload.url,
            payload.target_language,
        )

        return {
            "success": True,
            "session_id": session_id,
            "status": "buffering",
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


@app.get("/job/{session_id}")
def get_job_status(session_id: str):
    job = jobs.get(session_id)
    if not job:
        return {
            "success": False,
            "error": "Session not found",
        }

    return {
        "success": True,
        "session_id": session_id,
        "status": job["status"],
        "error": job["error"],
        "caption_count": len(job["captions"]),
    }


@app.get("/captions/{session_id}")
def get_captions(session_id: str):
    job = jobs.get(session_id)
    if not job:
        return {
            "success": False,
            "error": "Session not found",
            "captions": [],
        }

    return {
        "success": True,
        "session_id": session_id,
        "status": job["status"],
        "captions": job["captions"],
        "error": job["error"],
    }


@app.websocket("/ws/stream-media")
async def websocket_stream_media(websocket: WebSocket):
    await websocket.accept()
    
    try:
        config_text = await websocket.receive_text()
        config = json.loads(config_text)
        target_language = config.get("target_language", "english")
        media_type = config.get("media_type", "audio")
        
        target_key = target_language.strip().lower()
        if target_key not in LANGUAGE_MAP:
            target_key = "english"
        source_key = "english"
        
        process = await asyncio.create_subprocess_exec(
            'ffmpeg', '-i', 'pipe:0', '-f', 's16le', '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1', 'pipe:1',
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        )
        
        async def read_ws_to_ffmpeg():
            try:
                while True:
                    data = await websocket.receive_bytes()
                    if not data:
                        # Empty byte signifies end of stream from client
                        break
                    if process.stdin:
                        process.stdin.write(data)
                        await process.stdin.drain()
            except WebSocketDisconnect:
                pass
            except Exception as e:
                print(f"WS Read Error: {e}")
            finally:
                if process.stdin:
                    process.stdin.close()
        
        async def read_ffmpeg_stdout():
            chunk_size = 16000 * 2 * 4  # 4 seconds of 16kHz 16-bit PCM
            start_time = 0.0
            
            try:
                while True:
                    if not process.stdout:
                        break
                    pcm_chunk = await process.stdout.readexactly(chunk_size)
                    
                    duration_seconds = len(pcm_chunk) / (16000 * 2)
                    audio_data = sr.AudioData(pcm_chunk, 16000, 2)
                    try:
                        source_text = await asyncio.to_thread(recognize_chunk, audio_data, source_key)
                        if source_text:
                            translated_text = await asyncio.to_thread(translate_text, source_text, source_key, target_key)
                            
                            caption = {
                                "start": round(start_time, 2),
                                "end": round(start_time + duration_seconds, 2),
                                "source_text": source_text,
                                "translated_text": translated_text.strip() if translated_text else "",
                            }
                            await websocket.send_json(caption)
                    except Exception:
                        pass
                    
                    start_time += duration_seconds
            except asyncio.IncompleteReadError as e:
                # Final chunk
                pcm_chunk = e.partial
                if pcm_chunk:
                    duration_seconds = len(pcm_chunk) / (16000 * 2)
                    audio_data = sr.AudioData(pcm_chunk, 16000, 2)
                    try:
                        source_text = await asyncio.to_thread(recognize_chunk, audio_data, source_key)
                        if source_text:
                            translated_text = await asyncio.to_thread(translate_text, source_text, source_key, target_key)
                            
                            caption = {
                                "start": round(start_time, 2),
                                "end": round(start_time + duration_seconds, 2),
                                "source_text": source_text,
                                "translated_text": translated_text.strip() if translated_text else "",
                            }
                            await websocket.send_json(caption)
                    except Exception:
                        pass
        
        await asyncio.gather(
            read_ws_to_ffmpeg(),
            read_ffmpeg_stdout()
        )
        
        await process.wait()
        await websocket.send_json({"status": "done"})
        await websocket.close()
        
    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"WS error: {e}")
        try:
            await websocket.send_json({"error": str(e)})
            await websocket.close()
        except:
            pass

# --- Dictionary Integration ---
def safe_translate(text: str, source_lang: str, target_lang: str) -> str:
    if source_lang == target_lang: return text
    lang_mapping = {
        "english": "en", "en": "en",
        "hindi": "hi", "hi": "hi",
        "tamil": "ta", "ta": "ta",
        "telugu": "te", "te": "te",
        "malayalam": "ml", "ml": "ml",
    }
    src = lang_mapping.get(source_lang.lower(), "auto")
    tgt = lang_mapping.get(target_lang.lower(), "en")
    try:
        return GoogleTranslator(source=src, target=tgt).translate(text)
    except Exception:
        return text

def safe_translate_batch(texts: list, source_lang: str, target_lang: str) -> list:
    if source_lang == target_lang: return texts
    lang_mapping = {
        "english": "en", "en": "en",
        "hindi": "hi", "hi": "hi",
        "tamil": "ta", "ta": "ta",
        "telugu": "te", "te": "te",
        "malayalam": "ml", "ml": "ml",
    }
    src = lang_mapping.get(source_lang.lower(), "auto")
    tgt = lang_mapping.get(target_lang.lower(), "en")
    try:
        return GoogleTranslator(source=src, target=tgt).translate_batch(texts)
    except Exception:
        return texts

_IMAGE_CACHE: dict = {}

def get_image_url(word: str) -> str:
    if word in _IMAGE_CACHE:
        return _IMAGE_CACHE[word]
    url = f"https://api.pexels.com/v1/search?query={word}&per_page=1"
    headers = {"Authorization": PEXELS_KEY}
    try:
        response = requests.get(url, headers=headers, timeout=3)
        data = response.json()
        if "photos" in data and len(data["photos"]) > 0:
            result = data["photos"][0]["src"]["medium"]
        else:
            result = f"https://dummyimage.com/200x100/4a4a8a/ffffff.png&text={word}"
        _IMAGE_CACHE[word] = result
        return result
    except Exception:
        result = f"https://dummyimage.com/200x100/4a4a8a/ffffff.png&text={word}"
        _IMAGE_CACHE[word] = result
        return result

USER_MEMORY_FILE = BASE_DIR / "user_dict.json"

def load_user_dict():
    if USER_MEMORY_FILE.exists():
        try:
            with open(USER_MEMORY_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

LANG_CODE_MAP = {
    "english": "en", "en": "en",
    "hindi": "hi", "hi": "hi",
    "tamil": "ta", "ta": "ta",
    "telugu": "te", "te": "te",
    "malayalam": "ml", "ml": "ml",
}

@app.get("/dictionary/{lang_code}/{word}")
async def get_dictionary_meaning(lang_code: str, word: str):
    user_dict = load_user_dict()
    lemmatizer = WordNetLemmatizer()
    tgt_code = LANG_CODE_MAP.get(lang_code.lower(), "en")
    
    # Step 1: translate the word to English if needed (to look up in WordNet)
    if tgt_code == "en":
        eng_word = word.strip().lower()
    else:
        eng_word = await asyncio.to_thread(safe_translate, word, lang_code, "en")
        eng_word = (eng_word or word).strip().lower()

    img_query = eng_word

    # Step 2: look up WordNet synsets
    synsets = wn.synsets(eng_word)
    if not synsets:
        for pos in ('v', 'n', 'a'):
            lemma = lemmatizer.lemmatize(eng_word, pos=pos)
            synsets = wn.synsets(lemma)
            if synsets:
                img_query = lemma
                break

    if synsets:
        en_meaning = synsets[0].definition()
        en_synonyms = set()
        for s in synsets:
            en_synonyms.update([lm.name().replace('_', ' ') for lm in s.lemmas()])
        en_synonyms_list = list(en_synonyms)[:5]

        # Step 3: run image fetch and translation in parallel
        async def do_translate():
            if tgt_code == "en":
                return [en_meaning] + en_synonyms_list
            return await asyncio.to_thread(
                safe_translate_batch, [en_meaning] + en_synonyms_list, "en", lang_code
            )

        img_url_task = asyncio.to_thread(get_image_url, img_query)
        trans_task = do_translate()

        img_url, translated = await asyncio.gather(img_url_task, trans_task)

        meaning_trans = translated[0] if translated else en_meaning
        synonyms_trans = list(translated[1:]) if len(translated) > 1 else []
    else:
        # Fallback for unknown words
        img_url_task = asyncio.to_thread(get_image_url, eng_word)
        meaning_trans = f"No definition found for '{word}'."
        synonyms_trans = []
        img_url = await img_url_task

    synonym = user_dict.get(word)
    chosen = synonym if synonym else (synonyms_trans[0] if synonyms_trans else "")

    return {
        "word": word,
        "lang": lang_code,
        "meaning": meaning_trans,
        "synonym": chosen,
        "all_synonyms": synonyms_trans,
        "image_url": img_url
    }

class GestureRequest(BaseModel):
    text: str

@app.get("/gesture/phrases")
async def get_all_phrases():
    """Return all available phrase keys for autocomplete."""
    return {"phrases": sorted(PHRASE_MAPPING.keys())}

@app.post("/gesture/search")
async def search_gesture(req: GestureRequest):
    user_input = req.text.strip().lower()
    if not user_input:
        return {"success": False, "error": "Please enter some text"}

    # 1. Exact match
    video_file = PHRASE_MAPPING.get(user_input)

    # 2. Word-level scoring match
    if not video_file:
        user_words = set(user_input.split())
        best_score = 0
        best_file = None
        for phrase, file in PHRASE_MAPPING.items():
            phrase_words = set(phrase.split())
            common = len(user_words & phrase_words)
            if common > best_score:
                best_score = common
                best_file = file
        if best_score > 0:
            video_file = best_file

    # 3. Substring match fallback
    if not video_file:
        for phrase, file in PHRASE_MAPPING.items():
            if user_input in phrase or phrase in user_input:
                video_file = file
                break

    if video_file:
        return {"success": True, "video": video_file}
    else:
        # Return closest suggestions
        from difflib import get_close_matches
        suggestions = get_close_matches(user_input, PHRASE_MAPPING.keys(), n=3, cutoff=0.4)
        return {
            "success": False,
            "message": "No matching sign language found.",
            "suggestions": suggestions
        }

def classify_gesture(landmarks) -> str:
    """Basic heuristic to map hand landmarks to a word"""
    if not landmarks: return ""
    
    # Calculate simple bounding box / finger states for heuristic matching
    # Mediapipe landmarks are 0..20 (0 is wrist, 4,8,12,16,20 are fingertips)
    thumb_tip = landmarks[4]
    thumb_mcp = landmarks[2]
    index_tip = landmarks[8]
    index_mcp = landmarks[5]
    middle_tip = landmarks[12]
    middle_mcp = landmarks[9]
    ring_tip = landmarks[16]
    ring_mcp = landmarks[13]
    pinky_tip = landmarks[20]
    pinky_mcp = landmarks[17]

    # Check which fingers are up (y coordinate is lower than mcp)
    fingers_up = [
        index_tip.y < index_mcp.y,
        middle_tip.y < middle_mcp.y,
        ring_tip.y < ring_mcp.y,
        pinky_tip.y < pinky_mcp.y
    ]
    # Thumb logic is a bit different depending on hand orientation, just check if it's far to the side or up
    thumb_up = thumb_tip.y < thumb_mcp.y

    up_count = sum(fingers_up)

    if up_count == 4 and thumb_up:
        return "Hello" # All fingers open (Open Palm)
    elif up_count == 0 and thumb_up:
        return "Good" # Thumbs up
    elif up_count == 2 and fingers_up[0] and fingers_up[1] and not thumb_up:
        return "Peace" # V sign
    elif up_count == 0 and not thumb_up:
        return "Sorry" # Fist
    elif up_count == 1 and fingers_up[3]: # Pinky up
        return "Help me"
    return ""

@app.websocket("/gesture/live")
async def gesture_live_feed(websocket: WebSocket):
    await websocket.accept()
    last_word = ""
    consecutive_frames = 0
    try:
        while True:
            data_str = await websocket.receive_text()
            try:
                payload = json.loads(data_str)
                type_ = payload.get("type")
                if type_ == "jpeg":
                    img_bytes = base64.b64decode(payload["data"])
                    np_arr = np.frombuffer(img_bytes, np.uint8)
                    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
                elif type_ == "raw_y":
                    width = int(payload["width"])
                    height = int(payload["height"])
                    img_bytes = base64.b64decode(payload["data"])
                    np_arr = np.frombuffer(img_bytes, np.uint8)
                    
                    if len(np_arr) >= width * height:
                        img_gray = np_arr[:width*height].reshape((height, width))
                        img = cv2.cvtColor(img_gray, cv2.COLOR_GRAY2BGR)
                    else:
                        continue
                else:
                    continue
            except json.JSONDecodeError:
                # Ignore non-json messages for now
                continue
            
            if img is None:
                continue

            # Process with Mediapipe
            img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            results = hands_detector.process(img_rgb)

            detected_word = ""

            if results.multi_hand_landmarks:
                for hand_landmarks in results.multi_hand_landmarks:
                    mp_drawing.draw_landmarks(img, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                    
                    # Classify first hand
                    word = classify_gesture(hand_landmarks.landmark)
                    if word:
                        detected_word = word
                        break

            # Encode processed image back to base64
            _, buffer = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 60])
            processed_b64 = base64.b64encode(buffer).decode('utf-8')
            
            # Stabilization: only send word if it's detected consistently
            send_word = ""
            if detected_word and detected_word == last_word:
                consecutive_frames += 1
                if consecutive_frames == 10: # Word held for 10 frames (~1 sec)
                    send_word = detected_word
            elif detected_word != last_word:
                last_word = detected_word
                consecutive_frames = 0

            response = {
                "image": f"data:image/jpeg;base64,{processed_b64}",
                "word": send_word
            }
            await websocket.send_text(json.dumps(response))
            
    except WebSocketDisconnect:
        print("Client disconnected from /gesture/live")
    except Exception as e:
        print(f"Error in /gesture/live: {e}")