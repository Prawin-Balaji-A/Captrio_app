import nltk
from nltk.corpus import wordnet as wn
from nltk.stem import WordNetLemmatizer
import requests
import json
import os

# Uncomment these the first time you run:
# nltk.download('wordnet')
# nltk.download('omw-1.4')

PEXELS_KEY = "1MAZ1kwZKpAhXlvkq37iL5ObycViTqgdw7R4k2I1jCK9Ugjjnm3hL2hi"  # <-- Enter your Pexels API key here
USER_MEMORY_FILE = "user_dict.json"

def detect_lang(word):
    if any('\u0900' <= ch <= '\u097F' for ch in word): return "hi"
    if any('\u0D00' <= ch <= '\u0D7F' for ch in word): return "ml"
    if any('\u0B80' <= ch <= '\u0BFF' for ch in word): return "ta"
    if any('\u0C00' <= ch <= '\u0C7F' for ch in word): return "te"
    if any('\u0C80' <= ch <= '\u0CFF' for ch in word): return "kn"
    if any('\u0980' <= ch <= '\u09FF' for ch in word): return "bn"
    return "en"

def translate(word, src, tgt):
    url = "https://translate.googleapis.com/translate_a/single"
    params = {"client": "gtx", "sl": src, "tl": tgt, "dt": "t", "q": word}
    try:
        resp = requests.get(url, params=params, timeout=5)
        if resp.status_code == 200:
            result = resp.json()
            return result[0][0][0]
    except Exception:
        pass
    return word

def get_image_url(word):
    url = f"https://api.pexels.com/v1/search?query={word}&per_page=1"
    headers = {"Authorization": PEXELS_KEY}
    try:
        response = requests.get(url, headers=headers, timeout=5)
        data = response.json()
        if "photos" in data and len(data["photos"]) > 0:
            return data["photos"][0]["src"]["medium"]
        return f"https://dummyimage.com/200x100/cccccc/000000.png&text={word}"
    except Exception:
        return f"https://dummyimage.com/200x100/cccccc/000000.png&text={word}"

def load_user_dict():
    if os.path.exists(USER_MEMORY_FILE):
        try:
            with open(USER_MEMORY_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_user_dict(user_dict):
    with open(USER_MEMORY_FILE, "w", encoding="utf-8") as f:
        json.dump(user_dict, f, ensure_ascii=False, indent=2)

def process_word(word, lang_code, user_dict):
    lemmatizer = WordNetLemmatizer()
    eng_word = translate(word, lang_code, "en").strip().lower()
    if not eng_word:
        eng_word = word
    img_query = eng_word

    synsets = wn.synsets(eng_word)
    if not synsets:
        lemma = lemmatizer.lemmatize(eng_word, pos='v')
        synsets = wn.synsets(lemma)
        if not synsets:
            lemma = lemmatizer.lemmatize(eng_word, pos='n')
            synsets = wn.synsets(lemma)
        if synsets:
            eng_word = lemma
            img_query = eng_word

    if synsets:
        en_meaning = synsets[0].definition()
        en_synonyms = set()
        for s in synsets:
            en_synonyms.update([lemma.name().replace('_', ' ') for lemma in s.lemmas()])
        meaning_trans = translate(en_meaning, "en", lang_code)
        synonyms_trans = [translate(s, "en", lang_code) for s in list(en_synonyms)[:5]]
        img_url = get_image_url(img_query)
    else:
        fallback_root = {"ml": "protect", "hi": "protect", "ta": "protect", "te": "protect", "kn": "protect", "bn": "protect"}
        root_english = fallback_root.get(lang_code, "protect")
        meaning_trans = translate(root_english, "en", lang_code)
        synonyms_trans = []
        img_url = get_image_url(root_english)

    synonym = user_dict.get(word)
    if not synonym:
        # Prompt only in interactive mode!
        try:
            print(f"\nWord: {word} ({lang_code})")
            print(f"Meaning: {meaning_trans}")
            print(f"Synonyms: {', '.join(synonyms_trans) if synonyms_trans else 'None'}")
            synonym = input(f"Enter your preferred synonym for '{word}' (or press Enter to skip): ").strip()
        except Exception:
            synonym = ""
        if synonym:
            user_dict[word] = synonym
            save_user_dict(user_dict)
    chosen = synonym if synonym else (synonyms_trans[0] if synonyms_trans else "")

    return {
        "word": word,
        "lang": lang_code,
        "meaning": meaning_trans,
        "synonym": chosen,
        "all_synonyms": synonyms_trans,
        "image_url": img_url
    }

def get_words_from_file(filepath):
    with open(filepath, "r", encoding="utf-8") as fi:
        items = []
        for line in fi:
            line = line.strip()
            if not line:
                continue
            word = line
            lang = detect_lang(word)
            items.append((word, lang))
        return items

def main(input_path="input.txt", output_path="output.txt"):
    user_dict = load_user_dict()
    words_list = get_words_from_file(input_path)
    results = []
    for word, lang_code in words_list:
        out = process_word(word, lang_code, user_dict)
        results.append(
            f"{out['word']} ({out['lang']}):\n"
            f"  Meaning: {out['meaning']}\n"
            f"  Synonym: {out['synonym']}\n"
            f"  All synonyms: {', '.join(out['all_synonyms']) if out['all_synonyms'] else 'None'}\n"
            f"  Image: {out['image_url']}\n"
        )
    with open(output_path, "w", encoding="utf-8") as fo:
        fo.write("\n".join(results))
    print(f"\nWritten results to {output_path}")

if __name__ == "__main__":
    main()
