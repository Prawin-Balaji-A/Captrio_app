import sounddevice as sd
import numpy as np
import speech_recognition as sr
from deep_translator import GoogleTranslator

class LiveSpeechTranslation:
    def __init__(self):
        """
        Initialize live speech translation
        """
        self.sample_rate = 16000
        self.recognizer = sr.Recognizer()
        self.source_language = None
        self.target_language = None
        
    def select_languages(self):
        """Let user select source and target languages"""
        print("\n" + "=" * 60)
        print("Select Languages / भाषा चुनें / மொழிகளைத் தேர்ந்தெடுக்கவும்")
        print("=" * 60)
        
        languages = {
            '1': ('en-IN', 'en', 'English'),
            '2': ('hi-IN', 'hi', 'Hindi (हिंदी)'),
            '3': ('ta-IN', 'ta', 'Tamil (தமிழ்)'),
            '4': ('te-IN', 'te', 'Telugu (తెలుగు)'),
            '5': ('bn-IN', 'bn', 'Bengali (বাংলা)'),
            '6': ('mr-IN', 'mr', 'Marathi (मराठी)'),
            '7': ('gu-IN', 'gu', 'Gujarati (ગુજરાતી)'),
            '8': ('kn-IN', 'kn', 'Kannada (ಕನ್ನಡ)'),
            '9': ('ml-IN', 'ml', 'Malayalam (മലയാളം)'),
            '10': ('pa-IN', 'pa', 'Punjabi (ਪੰਜਾਬੀ)'),
        }
        
        print("\nAvailable Languages:")
        for key, (speech_code, trans_code, name) in languages.items():
            print(f"{key}. {name}")
        print("=" * 60)
        
        # Select SOURCE language (what you speak)
        while True:
            choice = input("\nSelect SOURCE language (what you will SPEAK) [1-10]: ").strip()
            if choice in languages:
                self.source_language = languages[choice]
                print(f"✅ Source: {self.source_language[2]}")
                break
            else:
                print("❌ Invalid choice. Please enter 1-10.")
        
        # Select TARGET language (output)
        while True:
            choice = input("\nSelect TARGET language (OUTPUT translation) [1-10]: ").strip()
            if choice in languages:
                self.target_language = languages[choice]
                print(f"✅ Target: {self.target_language[2]}")
                break
            else:
                print("❌ Invalid choice. Please enter 1-10.")
    
    def transcribe_and_translate(self, audio_data):
        """Transcribe in source language and translate to target"""
        try:
            # Convert numpy array to AudioData
            audio_int16 = (audio_data * 32767).astype(np.int16)
            audio_bytes = audio_int16.tobytes()
            audio = sr.AudioData(audio_bytes, self.sample_rate, 2)
            
            # Transcribe in source language
            source_text = self.recognizer.recognize_google(audio, language=self.source_language[0])
            
            if not source_text:
                return None, None
            
            # If source and target are same, no translation
            if self.source_language[1] == self.target_language[1]:
                return source_text, source_text
            
            # Translate to target language
            translator = GoogleTranslator(source=self.source_language[1], target=self.target_language[1])
            translated_text = translator.translate(source_text)
            
            return source_text, translated_text
        
        except sr.UnknownValueError:
            return None, None
        except Exception as e:
            print(f"❌ Error: {e}")
            return None, None
    
    def start_recording(self, chunk_duration=5):
        """Start live recording and translation"""
        print("\n" + "=" * 60)
        print(f"🎤 Speak in: {self.source_language[2]}")
        print(f"📝 Output in: {self.target_language[2]}")
        print("=" * 60)
        print("\nPress Ctrl+C to stop or change languages.\n")
        
        try:
            while True:
                print("🔴 Recording...")
                
                # Record audio
                audio_data = sd.rec(
                    int(chunk_duration * self.sample_rate),
                    samplerate=self.sample_rate,
                    channels=1,
                    dtype='float32'
                )
                sd.wait()
                
                print("⏳ Translating...")
                
                # Transcribe and translate
                original, translated = self.transcribe_and_translate(audio_data.flatten())
                
                if translated:
                    if original != translated:
                        print(f"📝 You said ({self.source_language[2]}): {original}")
                        print(f"✅ Translation ({self.target_language[2]}): {translated}\n")
                    else:
                        print(f"✅ Output: {translated}\n")
                else:
                    print("⚠️ No speech detected\n")
        
        except KeyboardInterrupt:
            print("\n\n✅ Recording stopped.")
            
            change = input("\nChange languages? (y/n): ").strip().lower()
            if change == 'y':
                self.select_languages()
                self.start_recording(chunk_duration)


if __name__ == "__main__":
    print("=" * 60)
    print("LIVE SPEECH TRANSLATION")
    print("=" * 60)
    
    stt = LiveSpeechTranslation()
    stt.select_languages()
    stt.start_recording(chunk_duration=5)
