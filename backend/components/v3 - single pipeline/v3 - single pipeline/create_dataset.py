# create_dataset.py

import os
import pickle
import cv2
import mediapipe as mp
from tqdm import tqdm

DATA_DIR = './data'
OUTPUT_PICKLE = 'data.pickle'

mp_hands = mp.solutions.hands

def extract_two_hand_features(image_bgr, hands_detector):
    img_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    results = hands_detector.process(img_rgb)

    if not results.multi_hand_landmarks:
        return None

    detected_hands = sorted(results.multi_hand_landmarks,
                            key=lambda hl: hl.landmark[0].x)

    data_aux = []

    for hand_landmarks in detected_hands[:2]:
        xs = [lm.x for lm in hand_landmarks.landmark]
        ys = [lm.y for lm in hand_landmarks.landmark]
        min_x = min(xs)
        min_y = min(ys)

        for lm in hand_landmarks.landmark:
            data_aux.append(lm.x - min_x)
            data_aux.append(lm.y - min_y)

    while len(data_aux) < 84:
        data_aux.append(0.0)

    return data_aux


def main():
    data, labels = [], []

    hands = mp_hands.Hands(static_image_mode=True,
                           max_num_hands=2,
                           min_detection_confidence=0.3)

    class_folders = [f for f in os.listdir(DATA_DIR) if os.path.isdir(os.path.join(DATA_DIR, f))]
    total_images = sum(len(os.listdir(os.path.join(DATA_DIR, c))) for c in class_folders)

    print(f"Extracting features from {total_images} images...")

    with tqdm(total=total_images, desc="Processing images") as pbar:
        for class_name in class_folders:
            folder_path = os.path.join(DATA_DIR, class_name)

            for img_name in os.listdir(folder_path):
                img = cv2.imread(os.path.join(folder_path, img_name))
                if img is None:
                    pbar.update(1)
                    continue

                features = extract_two_hand_features(img, hands)
                if features:
                    data.append(features)
                    labels.append(class_name)

                pbar.update(1)

    with open(OUTPUT_PICKLE, 'wb') as f:
        pickle.dump({'data': data, 'labels': labels}, f)

    print(f"Saved dataset to {OUTPUT_PICKLE}")
    print(f"Total usable samples: {len(data)}")


if __name__ == "__main__":
    main()
