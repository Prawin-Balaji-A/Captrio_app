# collect_images.py

import os
import cv2
import subprocess
import sys
from tqdm import tqdm
import shutil

DATA_DIR = './data'
os.makedirs(DATA_DIR, exist_ok=True)

print("\n=== SIGN LANGUAGE DATA COLLECTION PIPELINE ===\n")

# ----- USER INPUTS -----
num_signs = int(input("How many signs do you want to collect? "))
dataset_size = int(input("How many images per sign? "))

# Camera index
CAM_INDEX = 0

cap = cv2.VideoCapture(CAM_INDEX)
if not cap.isOpened():
    print(f"ERROR: Could not open camera with index {CAM_INDEX}")
    sys.exit(1)

for i in range(num_signs):
    while True:
        label = input(f"\nEnter label name for sign {i + 1}: ").strip()

        if not label:
            print("Label cannot be empty.")
            continue

        class_dir = os.path.join(DATA_DIR, label)

        if os.path.exists(class_dir):
            print(f"\n⚠ Dataset for '{label}' already exists!")
            print("\nChoose an option:")
            print("1 ➝ Add more samples to this class (APPEND)")
            print("2 ➝ Replace existing dataset for this class (DELETE & RESTART)")
            print("3 ➝ Cancel and enter a new label")

            choice = input("Enter choice (1/2/3): ").strip()

            if choice == "1":
                print(f"Appending images to existing class '{label}'")
                break  # continue with this folder
            elif choice == "2":
                print(f"Deleting and recreating dataset for '{label}'...")
                shutil.rmtree(class_dir)
                os.makedirs(class_dir)
                break
            elif choice == "3":
                print("Enter a new label name.")
                continue
            else:
                print("Invalid choice. Try again.")
                continue
        else:
            os.makedirs(class_dir, exist_ok=True)
            break

    print(f'\n=== Collecting data for "{label}" ===')
    print("Show your sign. A preview will show first.")
    print('Press "Q" when ready to start capturing images.')

    # READY PHASE
    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        cv2.putText(frame, f'Label: {label} | Press "Q" to START',
                    (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.9,
                    (0, 255, 0), 2, cv2.LINE_AA)
        cv2.imshow('Collect Images', frame)

        if cv2.waitKey(25) & 0xFF == ord('q'):
            break

    print(f"Capturing {dataset_size} images for '{label}'...\n")

    # CAPTURE PHASE with Progress Bar
    for counter in tqdm(range(dataset_size), desc=f"Capturing {label}"):
        ret, frame = cap.read()
        if not ret:
            continue

        cv2.putText(frame,
                    f'Label: {label} | Image {counter + 1}/{dataset_size}',
                    (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.9,
                    (0, 255, 0), 2, cv2.LINE_AA)
        cv2.imshow('Collect Images', frame)
        cv2.waitKey(25)

        img_path = os.path.join(class_dir, f'{counter + len(os.listdir(class_dir))}.jpg')
        cv2.imwrite(img_path, frame)

print("\n📸 Image collection complete!")
cap.release()
cv2.destroyAllWindows()

print("\n=== STEP 2: Extracting features & creating dataset ===")
subprocess.call([sys.executable, "create_dataset.py"])

print("\n=== STEP 3: Training model ===")
subprocess.call([sys.executable, "train_classifier.py"])

print("\n🎉 DATA COLLECTION + TRAINING FINISHED SUCCESSFULLY!")
print("➡ Run real-time recognition using:")
print("python realtime_sign_tts_suggestions.py")
