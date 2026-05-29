# train_classifier.py

import pickle
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
from tqdm import tqdm

DATA_PICKLE = 'data.pickle'
MODEL_FILE = 'model.p'


def main():
    data_dict = pickle.load(open(DATA_PICKLE, 'rb'))
    data = np.asarray(data_dict['data'], dtype=float)
    labels = np.asarray(data_dict['labels'])

    print(f"Training on {len(data)} samples...")

    x_train, x_test, y_train, y_test = train_test_split(
        data, labels, test_size=0.2,
        shuffle=True, stratify=labels, random_state=42
    )

    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=None,
        random_state=42,
        n_jobs=-1
    )

    print("Training classifier...")
    for _ in tqdm(range(1), desc="Building RandomForest"):
        model.fit(x_train, y_train)

    y_pred = model.predict(x_test)
    acc = accuracy_score(y_test, y_pred)

    print(f"Model Accuracy: {acc * 100:.2f}%")

    classes = sorted(list(set(labels)))
    pickle.dump({'model': model, 'classes': classes}, open(MODEL_FILE, 'wb'))

    print(f"Saved model + classes to {MODEL_FILE}")


if __name__ == "__main__":
    main()
