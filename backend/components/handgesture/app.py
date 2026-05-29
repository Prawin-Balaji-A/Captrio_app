from flask import Flask, render_template, request, jsonify, send_from_directory
import csv
import os

app = Flask(__name__)

# Project paths
BASE_DIR = r'D:\Project\handgesture'
CSV_FILE = os.path.join(BASE_DIR, 'ISL_All_86_Phrases.csv')
GIF_FOLDER = os.path.join(BASE_DIR, 'gif')

def load_phrases_mapping():
    """Load CSV and create mapping of phrases to video files"""
    phrase_mapping = {}
    
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file)
            next(csv_reader, None)  # Skip header if exists
            
            for row in csv_reader:
                if len(row) >= 2:
                    phrases_text = row[0]  # Column A
                    video_file = row[1]     # Column B (video filename)
                    
                    # Split by "/" to get alternative phrases
                    phrases = [p.strip() for p in phrases_text.split('/')]
                    
                    # Map each phrase variant to the same video file
                    for phrase in phrases:
                        phrase_mapping[phrase.lower()] = video_file
                        
    except Exception as e:
        print(f"Error loading CSV: {e}")
    
    return phrase_mapping

# Load phrase mapping at startup
PHRASE_MAPPING = load_phrases_mapping()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/search', methods=['POST'])
def search_phrase():
    """Search for matching phrase and return video filename"""
    user_input = request.json.get('text', '').strip().lower()
    
    if not user_input:
        return jsonify({'error': 'Please enter some text'})
    
    # Search for matching phrase
    video_file = PHRASE_MAPPING.get(user_input)
    
    if video_file:
        return jsonify({'success': True, 'video': video_file})
    else:
        return jsonify({'success': False, 'message': 'No matching signal is available'})

@app.route('/videos/<filename>')
def serve_video(filename):
    """Serve video files from gif folder"""
    return send_from_directory(GIF_FOLDER, filename, mimetype='video/webm')

if __name__ == '__main__':
    app.run(debug=True, host='localhost', port=5000)
