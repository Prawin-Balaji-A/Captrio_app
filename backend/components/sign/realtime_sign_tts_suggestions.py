# realtime_sign_tts_suggestions.py

import pickle
import cv2
import mediapipe as mp
import pyttsx3
import json
import time
import os
import numpy as np

MODEL_FILE = 'model.p'
DATA_PICKLE = 'data.pickle'
SEMANTIC_DICT_FILE = 'semantic_dict.json'
USAGE_COUNT_FILE = 'usage_count.json'
OUTPUT_TEXT_FILE = 'wordbuilder_output.txt'

mp_hands = mp.solutions.hands


def load_json(filepath, default=None):
    """Load JSON file, return default if not found or invalid."""
    if default is None:
        default = {}
    try:
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        else:
            return default
    except Exception as e:
        print(f"Warning: Could not load {filepath}: {e}")
        return default


def save_json(filepath, data):
    """Save data to JSON file."""
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"Error saving {filepath}: {e}")


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


def get_hand_center(results):
    """
    Get the center position of the hand(s) for zone detection.
    Returns (x, y) normalized coordinates (0.0 to 1.0) or None.
    """
    if not results.multi_hand_landmarks:
        return None
    
    # Use the first detected hand
    hand_landmarks = results.multi_hand_landmarks[0]
    
    # Calculate center of palm (average of all landmarks)
    x_coords = [lm.x for lm in hand_landmarks.landmark]
    y_coords = [lm.y for lm in hand_landmarks.landmark]
    
    center_x = sum(x_coords) / len(x_coords)
    center_y = sum(y_coords) / len(y_coords)
    
    return (center_x, center_y)


def get_zone_from_position(x, y, num_zones=3):
    """
    Determine which zone the hand is in based on x position.
    Returns zone number (0, 1, 2) or None if outside zone area.
    Zone detection only active in top 40% of screen.
    """
    # Only detect zones in upper portion of screen (y < 0.4)
    if y > 0.4:
        return None
    
    # Divide x-axis into zones
    zone_width = 1.0 / num_zones
    
    for i in range(num_zones):
        if zone_width * i <= x < zone_width * (i + 1):
            return i
    
    return None


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


def get_semantic_suggestions(word, semantic_dict, usage_count, vocabulary, n=3):
    """
    Get suggestions for a word using semantic dictionary with usage-based ranking.
    Falls back to vocabulary-based suggestions if word not in semantic dict.
    """
    word_normalized = word.strip().lower().replace(' ', '_')
    
    # Try semantic dictionary first
    if word_normalized in semantic_dict:
        suggestions = semantic_dict[word_normalized].copy()
        
        # Sort by usage count (descending)
        suggestions.sort(key=lambda s: usage_count.get(s, 0), reverse=True)
        
        return suggestions[:n]
    
    # Fallback: use difflib on vocabulary
    import difflib
    word_clean = word.strip().lower()
    if not word_clean or not vocabulary:
        return []
    
    matches = difflib.get_close_matches(
        word_clean,
        [v.lower() for v in vocabulary],
        n=n,
        cutoff=0.1
    )
    
    # Convert back to original case
    result = []
    for match in matches:
        for v in vocabulary:
            if v.lower() == match:
                result.append(v)
                break
        else:
            result.append(match)
    
    return result


def draw_suggestion_zones(frame, suggestions, zone_progress, active_zone):
    """
    Draw suggestion zones at the top of the frame with visual feedback.
    """
    h, w, _ = frame.shape
    num_zones = len(suggestions)
    
    if num_zones == 0:
        return
    
    zone_height = 150
    zone_width = w // num_zones
    
    colors = [
        (100, 150, 255),  # Light blue
        (150, 255, 150),  # Light green
        (255, 150, 150)   # Light red
    ]
    
    for i, suggestion in enumerate(suggestions):
        x1 = i * zone_width
        x2 = (i + 1) * zone_width
        y1 = 0
        y2 = zone_height
        
        # Determine color based on active zone
        if active_zone == i:
            # Highlight active zone
            color = colors[i % len(colors)]
            alpha = 0.5 + (zone_progress[i] * 0.3)  # Brighten as progress increases
        else:
            # Dimmed inactive zones
            color = colors[i % len(colors)]
            alpha = 0.2
        
        # Draw semi-transparent rectangle
        overlay = frame.copy()
        cv2.rectangle(overlay, (x1, y1), (x2, y2), color, -1)
        cv2.addWeighted(overlay, alpha, frame, 1 - alpha, 0, frame)
        
        # Draw border
        border_color = (255, 255, 255) if active_zone == i else (150, 150, 150)
        border_thickness = 4 if active_zone == i else 2
        cv2.rectangle(frame, (x1, y1), (x2, y2), border_color, border_thickness)
        
        # Draw zone number
        cv2.putText(frame, f"ZONE {i + 1}",
                    (x1 + 20, y1 + 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 2)
        
        # Draw suggestion text (wrapped if needed)
        suggestion_text = suggestion[:30]  # Truncate long suggestions
        text_y = y1 + 80
        cv2.putText(frame, suggestion_text,
                    (x1 + 20, text_y),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)
        
        # Draw progress bar if this zone is active
        if active_zone == i and zone_progress[i] > 0:
            progress_bar_y = y2 - 25
            progress_bar_height = 15
            progress_bar_x1 = x1 + 20
            progress_bar_x2 = x2 - 20
            progress_bar_width = progress_bar_x2 - progress_bar_x1
            
            # Background
            cv2.rectangle(frame, 
                         (progress_bar_x1, progress_bar_y),
                         (progress_bar_x2, progress_bar_y + progress_bar_height),
                         (100, 100, 100), -1)
            
            # Progress fill
            fill_width = int(progress_bar_width * zone_progress[i])
            if fill_width > 0:
                cv2.rectangle(frame,
                             (progress_bar_x1, progress_bar_y),
                             (progress_bar_x1 + fill_width, progress_bar_y + progress_bar_height),
                             (0, 255, 0), -1)
            
            # Progress percentage
            percentage = int(zone_progress[i] * 100)
            cv2.putText(frame, f"{percentage}%",
                       (x1 + zone_width // 2 - 25, progress_bar_y - 5),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    
    # Draw instruction
    instruction_y = zone_height + 30
    cv2.putText(frame, "HOLD YOUR HAND IN A ZONE TO SELECT",
                (w // 2 - 250, instruction_y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)


def main():
    # ----- Load model & classes -----
    model_dict = pickle.load(open(MODEL_FILE, 'rb'))
    model = model_dict['model']
    classes = model_dict.get('classes', [])
    vocabulary = [str(c) for c in classes]

    print("Loaded model classes:", len(classes))

    # ----- Load semantic dictionary -----
    semantic_dict = load_json(SEMANTIC_DICT_FILE, {})
    print(f"Loaded semantic dictionary: {len(semantic_dict)} entries")

    # ----- Load usage count -----
    usage_count = load_json(USAGE_COUNT_FILE, {})
    print(f"Loaded usage count: {len(usage_count)} tracked phrases")

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
        # Threshold = mean + 4.5 * std
        thresh = mean_d + 4.5 * std_d
        class_centroids[cls_str] = centroid
        class_thresholds[cls_str] = thresh

    # ----- Init dummy TTS handle (we recreate engine per call) -----
    engine = None

    # ----- Camera -----
    cap = cv2.VideoCapture(0)

    # Make display window resizable
    cv2.namedWindow(
        "Sign Recognition - Hand Zone Selection",
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

    # For hold-to-commit (sign recognition)
    last_label = ""
    label_start_time = None
    HOLD_DURATION = 2.0  # seconds to hold same sign
    hold_committed = False

    # For zone-based suggestion selection
    zone_dwell_time = {}  # {zone_index: start_time}
    zone_progress = [0.0, 0.0, 0.0]  # Progress for each zone
    ZONE_DWELL_DURATION = 1.5  # seconds to hold hand in zone
    active_zone = None

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

        # Draw hand landmarks (if any)
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

                        # Get semantic suggestions with usage ranking
                        suggestions = get_semantic_suggestions(
                            current_label_internal,
                            semantic_dict,
                            usage_count,
                            vocabulary,
                            n=3
                        )
                else:
                    # raw_label not in centroids -> treat as unknown
                    current_label_internal = ""
                    display_label = "UNKNOWN SIGN"
        else:
            current_label_internal = ""
            display_label = "NO SIGN SHOWN"

        # ----- Zone-based suggestion selection -----
        now = time.time()
        hand_center = get_hand_center(results)
        
        if hand_center and len(suggestions) > 0:
            x, y = hand_center
            detected_zone = get_zone_from_position(x, y, num_zones=len(suggestions))
            
            if detected_zone is not None:
                active_zone = detected_zone
                
                # Initialize dwell time if not already tracking
                if detected_zone not in zone_dwell_time:
                    zone_dwell_time[detected_zone] = now
                
                # Calculate progress
                elapsed = now - zone_dwell_time[detected_zone]
                progress = min(elapsed / ZONE_DWELL_DURATION, 1.0)
                zone_progress[detected_zone] = progress
                
                # Selection complete
                if progress >= 1.0:
                    chosen_suggestion = suggestions[detected_zone]
                    sentence = append_word(sentence, chosen_suggestion)
                    
                    # Update usage count
                    usage_count[chosen_suggestion] = usage_count.get(chosen_suggestion, 0) + 1
                    save_json(USAGE_COUNT_FILE, usage_count)
                    
                    print(f"✓ Zone {detected_zone + 1} selected: {chosen_suggestion}")
                    
                    # Reset zone tracking
                    zone_dwell_time.clear()
                    zone_progress = [0.0, 0.0, 0.0]
                    active_zone = None
                    
                    # Small delay to prevent double selection
                    time.sleep(0.3)
            else:
                # Hand not in any zone - reset tracking
                zone_dwell_time.clear()
                zone_progress = [0.0, 0.0, 0.0]
                active_zone = None
        else:
            # No hand or no suggestions - reset tracking
            zone_dwell_time.clear()
            zone_progress = [0.0, 0.0, 0.0]
            active_zone = None

        # ----- Hold-to-commit logic (sign recognition) -----
        progress_sign = 0.0

        if current_label_internal:
            if current_label_internal == last_label:
                if label_start_time is None:
                    label_start_time = now
                elapsed = now - label_start_time
                progress_sign = min(elapsed / HOLD_DURATION, 1.0)

                if progress_sign >= 1.0 and not hold_committed:
                    sentence = append_word(sentence, current_label_internal)
                    # Update usage count for the signed word
                    usage_count[current_label_internal] = usage_count.get(current_label_internal, 0) + 1
                    save_json(USAGE_COUNT_FILE, usage_count)
                    hold_committed = True
            else:
                last_label = current_label_internal
                label_start_time = now
                hold_committed = False
                progress_sign = 0.0
        else:
            last_label = ""
            label_start_time = None
            hold_committed = False
            progress_sign = 0.0

        # ---------- UI DRAWING ----------
        
        # Draw suggestion zones first (at top)
        if len(suggestions) > 0:
            draw_suggestion_zones(frame, suggestions, zone_progress, active_zone)
        
        ui_blue = (128, 0, 0)   # dark blue in BGR
        white = (255, 255, 255)

        # Adjust UI positions to account for suggestion zones
        ui_offset = 180 if len(suggestions) > 0 else 0

        # Top title bar (below zones)
        title_y = ui_offset
        cv2.rectangle(frame, (0, title_y), (w, title_y + 35), ui_blue, -1)
        cv2.putText(frame, "SIGN TO SPEECH - HAND ZONE SELECTION",
                    (10, title_y + 25), cv2.FONT_HERSHEY_SIMPLEX, 0.7, white, 2)

        # CURRENT SIGN section bar
        current_bar_y1 = title_y + 60
        current_bar_y2 = current_bar_y1 + 30
        cv2.rectangle(frame, (10, current_bar_y1),
                      (380, current_bar_y2), ui_blue, -1)
        cv2.putText(frame, "CURRENT SIGN :", (20, current_bar_y2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, white, 2)

        # Current sign text
        cv2.putText(frame, display_label,
                    (400, current_bar_y2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)

        # Hold instruction for sign
        cv2.putText(frame, "HOLD SIGN TO AUTO ADD WORD",
                    (20, current_bar_y2 + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

        # Progress bar for sign hold
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
        if progress_sign > 0:
            fill_x2 = bar_x1 + int((bar_x2 - bar_x1) * progress_sign)
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
        cv2.imshow("Sign Recognition - Hand Zone Selection", frame)

        key = cv2.waitKey(1) & 0xFF

        # ----- Key handling -----
        if key in [ord('q'), ord('Q')]:
            break

        elif key in [ord('c'), ord('C')]:
            # manually commit current sign (only if known)
            if current_label_internal:
                sentence = append_word(sentence, current_label_internal)
                # Update usage count
                usage_count[current_label_internal] = usage_count.get(current_label_internal, 0) + 1
                save_json(USAGE_COUNT_FILE, usage_count)

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