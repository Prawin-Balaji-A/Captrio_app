# realtime_sign_tts_suggestions.py

import pickle
import cv2
import mediapipe as mp
import pyttsx3
import difflib
import time
import os
import numpy as np

MODEL_FILE = 'model.p'
DATA_PICKLE = 'data.pickle'
OUTPUT_TEXT_FILE = 'wordbuilder_output.txt'  # saved sentences

mp_hands = mp.solutions.hands


def extract_two_hand_features_from_results(results):
    """
    Returns a fixed-length feature vector for up to 2 hands.
    Same logic as in create_dataset.py.
    """
    if not results.multi_hand_landmarks:
        return None

    # Sort hands by x position (wrist landmark) for consistent ordering
    detected_hands = sorted(
        results.multi_hand_landmarks,
        key=lambda hl: hl.landmark[0].x
    )

    data_aux = []

    for hand_landmarks in detected_hands[:2]:
        xs = [lm.x for lm in hand_landmarks.landmark]
        ys = [lm.y for lm in hand_landmarks.landmark]
        min_x = min(xs)
        min_y = min(ys)

        for lm in hand_landmarks.landmark:
            data_aux.append(lm.x - min_x)
            data_aux.append(lm.y - min_y)

    expected_len = 42 * 2  # 2 hands * 21 landmarks * (x,y)
    while len(data_aux) < expected_len:
        data_aux.append(0.0)

    return data_aux


def speak_text(engine, text):
    text = text.strip()
    if not text:
        return
    # fresh engine each time (stable behaviour)
    engine = pyttsx3.init()
    engine.setProperty('rate', 150)
    engine.say(text)
    engine.runAndWait()


def append_word(sentence, word):
    word = word.strip()
    if not word:
        return sentence
    return f"{sentence} {word}".strip()


def main():
    # ----- Load model & classes -----
    model_dict = pickle.load(open(MODEL_FILE, 'rb'))
    model = model_dict['model']
    classes = model_dict.get('classes', [])
    vocabulary = [str(c) for c in classes]

    print("Loaded classes for suggestions:", vocabulary)

    # ----- Load data to build centroids for unknown-sign detection -----
    data_dict = pickle.load(open(DATA_PICKLE, 'rb'))
    X = np.asarray(data_dict['data'], dtype=float)
    y = np.asarray(data_dict['labels'])

    class_centroids = {}
    class_thresholds = {}

    for cls in classes:
        cls_str = str(cls)
        mask = (y == cls_str)
        X_c = X[mask]
        if X_c.size == 0:
            continue
        centroid = X_c.mean(axis=0)
        dists = np.linalg.norm(X_c - centroid, axis=1)
        mean_d = dists.mean()
        std_d = dists.std() if dists.size > 1 else 0.0
        # Threshold = mean + 2 * std
        thresh = mean_d + 4.5 * std_d
        class_centroids[cls_str] = centroid
        class_thresholds[cls_str] = thresh

    def get_suggestions(word, n=3):
        word_clean = word.strip().lower()
        if not word_clean or not vocabulary:
            return []
        return difflib.get_close_matches(
            word_clean,
            [v.lower() for v in vocabulary],
            n=n,
            cutoff=0.1  # low cutoff so we almost always get something
        )

    # ----- Init dummy TTS handle (we recreate engine per call) -----
    engine = None

    # ----- Camera -----
    cap = cv2.VideoCapture(0)

    # Make display window resizable
    cv2.namedWindow(
        "Sign Recognition - TTS + Suggestions + Wordbuilder",
        cv2.WINDOW_NORMAL
    )

    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    )

    current_label_internal = ""   # valid label or ''
    display_label = ""            # what we show: label / UNKNOWN / NO SIGN
    sentence = ""
    save_notification_time = 0
    save_message_duration = 1.5  # seconds

    suggestions = []

    # For hold-to-commit
    last_label = ""
    label_start_time = None
    HOLD_DURATION = 2.0  # seconds to hold same sign
    hold_committed = False

    # Make sure output file exists
    if not os.path.exists(OUTPUT_TEXT_FILE):
        with open(OUTPUT_TEXT_FILE, 'w', encoding='utf-8') as f:
            f.write("Wordbuilder saved sentences:\n")

    TARGET_W, TARGET_H = 1500, 950

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Resize early so UI coordinates are stable
        frame = cv2.resize(frame, (TARGET_W, TARGET_H))
        h, w, _ = frame.shape

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(frame_rgb)

        # Draw hand landmarks (if any) first
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp.solutions.drawing_utils.draw_landmarks(
                    frame,
                    hand_landmarks,
                    mp_hands.HAND_CONNECTIONS
                )

        # ----- Recognition + unknown-sign logic -----
        suggestions = []
        if results.multi_hand_landmarks:
            features = extract_two_hand_features_from_results(results)
            if features is not None:
                feat_arr = np.asarray(features, dtype=float)
                raw_pred = model.predict([feat_arr])[0]
                raw_label = str(raw_pred).strip()

                # Default to unknown
                current_label_internal = ""
                display_label = "UNKNOWN SIGN"

                if raw_label in class_centroids:
                    centroid = class_centroids[raw_label]
                    thresh = class_thresholds[raw_label]
                    dist = np.linalg.norm(feat_arr - centroid)

                    if dist <= thresh:
                        # Accept as known sign
                        current_label_internal = raw_label
                        display_label = raw_label

                        suggestions_raw = get_suggestions(current_label_internal, n=3)
                        # Suggestions are returned in lowercase; convert to original case if possible
                        for s in suggestions_raw:
                            for v in vocabulary:
                                if v.lower() == s:
                                    suggestions.append(v)
                                    break
                            else:
                                suggestions.append(s)
                else:
                    # raw_label not in centroids -> treat as unknown
                    current_label_internal = ""
                    display_label = "UNKNOWN SIGN"
        else:
            current_label_internal = ""
            display_label = "NO SIGN SHOWN"

        # ----- Hold-to-commit logic (only for known labels) -----
        now = time.time()
        progress = 0.0

        if current_label_internal:
            if current_label_internal == last_label:
                if label_start_time is None:
                    label_start_time = now
                elapsed = now - label_start_time
                progress = min(elapsed / HOLD_DURATION, 1.0)

                if progress >= 1.0 and not hold_committed:
                    sentence = append_word(sentence, current_label_internal)
                    hold_committed = True
            else:
                last_label = current_label_internal
                label_start_time = now
                hold_committed = False
                progress = 0.0
        else:
            last_label = ""
            label_start_time = None
            hold_committed = False
            progress = 0.0

        # ---------- UI DRAWING (based on your mock) ----------
        ui_blue = (128, 0, 0)   # dark blue in BGR
        white = (255, 255, 255)

        # Top title bar
        cv2.rectangle(frame, (0, 0), (w, 35), ui_blue, -1)
        cv2.putText(frame, "SIGN TO SPEECH INTERFACE",
                    (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.7, white, 2)

        # CURRENT SIGN section bar
        current_bar_y1, current_bar_y2 = 60, 90
        cv2.rectangle(frame, (10, current_bar_y1),
                      (380, current_bar_y2), ui_blue, -1)
        cv2.putText(frame, "CURRENT SIGN :", (20, current_bar_y2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, white, 2)

        # Current sign text
        cv2.putText(frame, display_label,
                    (400, current_bar_y2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)

        # Suggestion heading bar on right
        sugg_bar_y1, sugg_bar_y2 = 60, 90
        sugg_bar_x1, sugg_bar_x2 = w - 360, w - 10
        cv2.rectangle(frame, (sugg_bar_x1, sugg_bar_y1),
                      (sugg_bar_x2, sugg_bar_y2), ui_blue, -1)
        cv2.putText(frame, "SUGGESTIONS", (sugg_bar_x1 + 10, sugg_bar_y2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, white, 2)

        # Small text: [1-3] = suggestion selection
        cv2.putText(frame, "[1-3] = SUGGESTION SELECTION",
                    (sugg_bar_x1, sugg_bar_y2 + 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

        # Suggestions list
        for idx, sugg in enumerate(suggestions[:3]):
            text = f"{idx + 1}. {sugg}"
            cv2.putText(frame, text,
                        (sugg_bar_x1 + 10, sugg_bar_y2 + 55 + 25 * idx),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

        # Hold instruction
        cv2.putText(frame, "HOLD SIGN TO AUTO ADD WORD",
                    (20, current_bar_y2 + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

        # Progress bar (green inside grey bar)
        bar_x1 = 20
        bar_x2 = w // 2
        bar_y1 = current_bar_y2 + 50
        bar_y2 = bar_y1 + 20

        # Outer bar
        cv2.rectangle(frame, (bar_x1, bar_y1), (bar_x2, bar_y2),
                      (192, 192, 192), -1)  # grey
        cv2.rectangle(frame, (bar_x1, bar_y1), (bar_x2, bar_y2),
                      (100, 100, 100), 2)  # border

        # Filled part
        if progress > 0:
            fill_x2 = bar_x1 + int((bar_x2 - bar_x1) * progress)
            cv2.rectangle(frame, (bar_x1, bar_y1), (fill_x2, bar_y2),
                          (0, 255, 0), -1)

        # WORD BUILDER section
        wb_bar_y1, wb_bar_y2 = h - 170, h - 140
        cv2.rectangle(frame, (10, wb_bar_y1),
                      (320, wb_bar_y2), ui_blue, -1)
        cv2.putText(frame, "WORD BUILDER :", (20, wb_bar_y2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, white, 2)

        # Wordbuilder content
        cv2.putText(frame, sentence,
                    (20, wb_bar_y2 + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)

        # Shortcut keys block
        keys_y = h - 60
        cv2.putText(frame, "SHORTCUT KEYS:",
                    (20, wb_bar_y2 + 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

        shortcuts_text = (
            "[C]=COMMIT SIGN   "
            "[BACKSPACE]=DELETE   "
            "[X]=CLEAR   "
            "[S]=SAVE   "
            "[V]=VOICE   "
            "[SPACEBAR]=SPACE   "
            "[Q]=QUIT"
        )
        cv2.putText(frame, shortcuts_text,
                    (20, keys_y),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)
        # Show save notification
        if save_notification_time > 0:
            elapsed = time.time() - save_notification_time
            if elapsed < save_message_duration:
                cv2.putText(
                    frame,
                    "SAVED!",
                    (w - 130, h - 25),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (0, 200, 0),
                    2
                )
            else:
                save_notification_time = 0

        # Final show
        cv2.imshow("Sign Recognition - TTS + Suggestions + Wordbuilder", frame)

        key = cv2.waitKey(1) & 0xFF

        # ----- Key handling -----
        if key in [ord('q'), ord('Q')]:
            break

        elif key in [ord('c'), ord('C')]:
            # manually commit current sign (only if known)
            if current_label_internal:
                sentence = append_word(sentence, current_label_internal)

        elif key in [ord('1'), ord('2'), ord('3')]:
            idx = int(chr(key)) - 1
            if 0 <= idx < len(suggestions):
                chosen = suggestions[idx]
                sentence = append_word(sentence, chosen)

        elif key in (8, 127):  # BACKSPACE / DELETE
            words = sentence.split()
            if words:
                words.pop()
                sentence = " ".join(words)

        elif key in [ord('x'), ord('X')]:
            # clear sentence
            sentence = ""

        elif key in [ord('s'), ord('S')]:
            with open(OUTPUT_TEXT_FILE, 'a', encoding='utf-8') as f:
                f.write(sentence.strip() + "\n")
            save_notification_time = time.time()
            print(f"Saved sentence to {OUTPUT_TEXT_FILE}: {sentence}")

        elif key in [ord('v'), ord('V')]:
            # TTS: speak sentence
            speak_text(engine, sentence)

        elif key == 32:  # SPACEBAR
            if not sentence.endswith(" "):
                sentence += " "

    hands.close()
    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
