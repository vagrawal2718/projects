from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from moviepy.editor import ImageClip, concatenate_videoclips, AudioFileClip
import cv2
import tempfile
import numpy as np
#from flask_mysqldb import MySQL
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token
#import MySQLdb.cursors
from werkzeug.utils import secure_filename
from flask_wtf import FlaskForm
from wtforms import FileField, SubmitField
from wtforms.validators import DataRequired
from flask_wtf.file import FileField, FileRequired
from wtforms import StringField, TextAreaField, SelectMultipleField, validators
from wtforms import SubmitField
import mysql.connector
from flask import Flask, send_file, abort
import imghdr
import io
import base64
from flask import flash  # Import flash if you haven't already
import logging
from flask import send_from_directory
import re
import os
import json
#logging.basicConfig(filename='app.log', level=logging.INFO)

app = Flask(__name__)
app.secret_key = 'secret_key'
bcrypt = Bcrypt(app)
app.config['JWT_SECRET_KEY'] = '1a2b3c4d5e6d7g8h9i10'  # Change this to your JWT Secret Key
jwt = JWTManager(app)

import psycopg2
import psycopg2.extras 
from psycopg2 import connect, extras

# Function to check if an audio file already exists
def audio_exists(cursor, audio_name):
    cursor.execute("SELECT COUNT(*) FROM audio_library WHERE audio_name = %s", (audio_name,))
    return cursor.fetchone()[0] > 0

# Function to insert an audio file if it doesn't exist
def insert_audio(cursor, audio_name, audio_path):
    if not audio_exists(cursor, audio_name):
        # Read the binary data of the audio file
        with open(audio_path, 'rb') as f:
            audio_blob = f.read()
        
        # Insert the audio data into the database
        cursor.execute("""
            INSERT INTO audio_library (audio_name, audio_blob, audio_path, metadata) 
            VALUES (%s, %s, %s, %s)
            """, (audio_name, audio_blob, audio_path, '{}'))
current_directory = os.path.dirname(os.path.abspath(__file__))
print(f"Current directory: {current_directory}")
cert_path = os.path.join(current_directory, '.postgresql', 'root.crt')
print(f"Certificate path: {cert_path}")
# Read and print the certificate file
try:
    with open(cert_path, 'r') as cert_file:
        cert_contents = cert_file.read()
        print("Certificate contents:")
        print(cert_contents)
except FileNotFoundError:
    print("Certificate file not found.")
except Exception as e:
    print(f"An error occurred while reading the certificate: {e}")
    
connection_string1 = f"""
host=iiitmysql-8859.8nk.gcp-asia-southeast1.cockroachlabs.cloud 
port=26257 
dbname=loginapp 
user=avk 
password=vVwTyjQyFOrcNUcJ5ZAYiw
sslcert=
sslkey=
sslmode=verify-full
sslrootcert={cert_path}
"""
connection_string = f"""
host=iiitmysql-8859.8nk.gcp-asia-southeast1.cockroachlabs.cloud 
port=26257 
dbname=loginapp 
user=avk 
password=vVwTyjQyFOrcNUcJ5ZAYiw
sslmode=require
sslrootcert={cert_path}
"""
#user = "avk"
#password = "vVwTyjQyFOrcNUcJ5ZAYiw"
#host = "iiitmysql-8859.8nk.gcp-asia-southeast1.cockroachlabs.cloud"
#port = 26257
#dbname = "loginapp"
#sslmode = "verify-full"
#sslrootcert = cert_path  # Ensure this is the correct path to your root certificate

# Convert to the URI format
# connection_string = f"postgresql://{user}:{password}@{host}:{port}/{dbname}?sslmode={sslmode}&sslrootcert={sslrootcert}"
# Connect to CockroachDB
# print(f"Connection string: {connection_string}")
# connection_string = f"postgresql://avk:vVwTyjQyFOrcNUcJ5ZAYiw@iiitmysql-8859.8nk.gcp-asia-southeast1.cockroachlabs.cloud:26257/loginapp?sslmode=verify-full&sslrootcert=/opt/render/project/src/.postgresql/root.crt"
connection = psycopg2.connect(connection_string)
# Create a cursor object
cursor = connection.cursor()

# Assuming the connection is successful, create a cursor object and print it
if connection:
    cursor = connection.cursor()
    print(f"Cursor: {cursor}")

    # Execute SQL commands and print a success message for each
    try:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS accounts (
            id SERIAL PRIMARY KEY,
            username VARCHAR(255) NOT NULL,
            email VARCHAR(255) NOT NULL,
            password VARCHAR(255) NOT NULL
            );
        """)
        print("Created table 'accounts'.")

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS images (
            image_id SERIAL PRIMARY KEY,
            user_id INT NOT NULL,
            image_name VARCHAR(255) NOT NULL,
            image_path VARCHAR(255) NOT NULL,
            image BYTEA,
            metadata TEXT
            );
        """)
        print("Created table 'images'.")

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS audio_library (
            audio_id SERIAL PRIMARY KEY,
            audio_name VARCHAR(255) NOT NULL,
            audio_blob BYTEA NOT NULL,
            audio_path VARCHAR(255),
            metadata TEXT,
            uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        print("Created table 'audio_library'.")

        # Commit the changes
        connection.commit()
    except psycopg2.Error as e:
        print("An error occurred while executing SQL commands:")
        print(e)
else:
    print("No connection could be established to the database.")
    
cursor.execute("""
    CREATE TABLE IF NOT EXISTS accounts (
      id SERIAL PRIMARY KEY,
      username VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL,
      password VARCHAR(255) NOT NULL
    );
    CREATE TABLE IF NOT EXISTS images (
      image_id SERIAL PRIMARY KEY,
      user_id INT NOT NULL,
      image_name VARCHAR(255) NOT NULL,
      image_path VARCHAR(255) NOT NULL,
      image BYTEA,
      metadata TEXT
    );
    CREATE TABLE IF NOT EXISTS audio_library (
      audio_id SERIAL PRIMARY KEY,
      audio_name VARCHAR(255) NOT NULL,
      audio_blob BYTEA NOT NULL,
      audio_path VARCHAR(255),
      metadata TEXT,
      uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    # Commit changes and close the connection

connection.commit()

audio_dir = './audios'
audio_files = ['sample1.mp3', 'sample2.mp3', 'sample3.mp3', 'sample4.mp3', 'sample5.mp3']

# Iterate over each audio file and insert it if not exists
for audio_file in audio_files:
    audio_path = os.path.join(audio_dir, audio_file)
    insert_audio(cursor, audio_file, audio_path)

# Commit changes and close the connection
connection.commit()

#mysql = MySQL(app)

@app.route('/pythonlogin/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST' and 'username' in request.form and 'password' in request.form:
        username = request.form['username']
        password = request.form['password']
        with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
            cursor.execute('SELECT * FROM accounts WHERE username = %s', (username,))
            account = cursor.fetchone()
        if account and bcrypt.check_password_hash(account['password'], password):
            access_token = create_access_token(identity=username)
            session['loggedin'] = True
            session['id'] = account['id']
            session['username'] = account['username']
            session['jwt_token'] = access_token  # Storing JWT token in session
            return redirect(url_for('home'))
        else:
            flash("Incorrect username/password!", "danger")
    return render_template('auth/login.html', title="Login")

@app.route('/pythonlogin/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST' and 'username' in request.form and 'password' in request.form and 'email' in request.form:
        username = request.form['username']
        password = request.form['password']
        email = request.form['email']
        with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
            cursor.execute("SELECT * FROM accounts WHERE username LIKE %s", (username,))
            account = cursor.fetchone()
        if account:
            flash("Account already exists!", "danger")
        elif not re.match(r'[^@]+@[^@]+\.[^@]+', email):
            flash("Invalid email address!", "danger")
        elif not re.match(r'[A-Za-z0-9]+', username):
             flash("Username must contain only characters and numbers!", "danger")
        elif not username or not password or not email:
            flash("Please fill out the form!", "danger")
        else:
            hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
            with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
                cursor.execute('INSERT INTO accounts (username, email, password) VALUES (%s, %s, %s)', (username, email, hashed_password))
                #cursor.execute('INSERT INTO accounts VALUES (%s, %s, %s)', (username, email, hashed_password))
            connection.commit()
            flash("You have successfully registered!", "success")
            return redirect(url_for('login'))
    elif request.method == 'POST':
        flash("Please fill out the form!", "danger")
    return render_template('auth/register.html', title="Register")

@app.route('/')
def home():
    if 'loggedin' in session:
        user_id = session['id']
        with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
            cursor.execute('SELECT * FROM images WHERE user_id = %s', (user_id,))
            images = cursor.fetchall()  # Fetches all user's images
        return render_template('home/home.html', username=session['username'], images=images)
    else:
        return redirect(url_for('login'))

@app.route('/profile')
def profile():
    if 'loggedin' in session:
        # Retrieve user account details from the database using the stored session['id']
        with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
            cursor.execute('SELECT * FROM accounts WHERE id = %s', (session['id'],))
            account = cursor.fetchone()  # This fetches the user's account details as a dictionary
        # Check if account details are found
        if account:
            return render_template('auth/profile.html', account=account, title="Profile")
        else:
            # If no account found with the session ID, clear the session and redirect to login
            session.pop('loggedin', None)
            session.pop('id', None)
            session.pop('username', None)
            flash("Unable to find account details.", "danger")
            return redirect(url_for('login'))
    else:
        return redirect(url_for('login'))

# App configuration
UPLOAD_FOLDER = './static/images/'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

class UploadForm(FlaskForm):
    file = FileField('Image File', validators=[FileRequired()], render_kw={"multiple": True})
    submit = SubmitField('Save Images')

def store_image_in_db(user_id, file_path, file_name, metadata):
    # Open the file in binary mode
    with open(file_path, 'rb') as file:
        binary_data = file.read()  # Read the entire file as binary data

    try:
        with connection.cursor() as cursor:
            # Adjusted SQL query to include the binary data
            sql_insert_query = """ INSERT INTO images (user_id, image_name, image_path, image, metadata) VALUES (%s, %s, %s, %s, %s)"""
            cursor.execute(sql_insert_query, (user_id, file_name, file_path, binary_data, metadata))
            connection.commit()
            print("Image inserted successfully into the images table")
    except Exception as e:
            print(f"Failed to insert image into MySQL table {e}")

@app.route('/upload', methods=['GET', 'POST'])
def upload_file():
    if 'loggedin' not in session:
        return redirect(url_for('login'))
    form = UploadForm()
    if request.method == 'POST' and form.validate_on_submit():
        user_id = session['id']
        files = request.files.getlist('file')  # Adjusted for correct form field name
        successful_uploads = 0
        for file in files:
            if file and allowed_file(file.filename):
                filename = secure_filename(f"{user_id}_{file.filename}")
                user_folder = os.path.join(app.config['UPLOAD_FOLDER'], str(user_id))
                if not os.path.exists(user_folder):
                    os.makedirs(user_folder)
                file_path = os.path.join(user_folder, filename)
                file.save(file_path)
                store_image_in_db(user_id, file_path, filename, "{}") 
                successful_uploads += 1
        if successful_uploads:
            flash(f'Successfully uploaded {successful_uploads} images.', 'success')
            return redirect(url_for('upload_file'))  
        else:
            flash('No files were uploaded.', 'danger')
    return render_template('home/upload.html', form=form)

@app.route('/image/<int:image_id>')
def serve_image(image_id):
    with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
        cursor.execute('SELECT image, image_name FROM images WHERE image_id = %s', (image_id,))
        image = cursor.fetchone()
    if image:
        try:
            # Convert memoryview to bytes if necessary
            image_data = image['image'].tobytes() if isinstance(image['image'], memoryview) else image['image']
            image_binary = io.BytesIO(image_data)
            image_format = imghdr.what(None, h=image_data)
            mimetype = f'image/{image_format}' if image_format else 'application/octet-stream'
            return send_file(image_binary, mimetype=mimetype, as_attachment=False)
        except Exception as e:
            print(f"Error serving image: {e}")
            abort(500)
    else:
        abort(404)

@app.route('/serve_audio/<int:audio_id>')
def serve_audio(audio_id):
    with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
        cursor.execute('SELECT audio_blob, audio_name FROM audio_library WHERE audio_id = %s', (audio_id,))
        audio = cursor.fetchone()
    if audio:
        try:
            # Convert memoryview to bytes if necessary
            audio_data = audio['audio_blob'].tobytes() if isinstance(audio['audio_blob'], memoryview) else audio['audio_blob']
            audio_binary = io.BytesIO(audio_data)
            mimetype = 'audio/mpeg'  # Assuming all audio files are mp3 format
            return send_file(audio_binary, mimetype=mimetype, as_attachment=False)
        except Exception as e:
            print(f"Error serving audio: {e}")
            abort(500)
    else:
        abort(404)

class VideoCreationForm(FlaskForm):
    videoTitle = StringField('Video Title', [validators.DataRequired()])
    videoDescription = TextAreaField('Video Description')
    imageSelect = SelectMultipleField('Select Images for Video', coerce=int)

@app.route('/create', methods=['GET', 'POST'])
def create():
    if 'loggedin' not in session:
        return redirect(url_for('login'))

    form = VideoCreationForm(request.form)
    user_id = session['id']
    output_video_path = None  # Initialize the variable to ensure it's set

    # Initialize cursor outside of the POST block to fetch images and audio files for the user
    with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
        cursor.execute('SELECT image_id, image_name, image_path FROM images WHERE user_id = %s', (user_id,))
        images = cursor.fetchall()
        cursor.execute('SELECT audio_id, audio_name, audio_path FROM audio_library')
        audio_files = cursor.fetchall()

    # Handle form submission
    if request.method == 'POST' and form.validate():
        video_title = form.videoTitle.data
        video_description = form.videoDescription.data

        # Get the selected images and durations from the form
        selected_images = json.loads(request.form['selected_images'])
        selected_audio_id = request.form['selectedAudio']
        resolution_choice = request.form['resolution']
        quality_choice = request.form['quality']

        # Map resolution and quality selections to actual values
        resolution_map = {'480': (640, 480), '720': (1280, 720), '1080': (1920, 1080), '2160': (3840, 2160)}
        quality_map = {'low': '500k', 'medium': '1000k', 'high': '2000k'}
        resolution = resolution_map.get(resolution_choice, (1280, 720))
        quality = quality_map.get(quality_choice, 'medium')

        try:
            image_clips = []
            for selection in selected_images:
                image_id = selection['id']
                duration = float(selection['duration'])
                with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
                    cursor.execute('SELECT image_path FROM images WHERE image_id = %s AND user_id = %s', (image_id, user_id))
                    image_record = cursor.fetchone()
                if image_record:
                    image_record_path = image_record['image_path']
                if image_record_path.startswith('./static/'):
                    image_record_path = image_record_path[len('./static/'):]
                
                # Construct a normalized path
                normalized_image_path = os.path.normpath(image_record_path)
                
                # Combine it with the static folder path
                image_path = os.path.join(app.static_folder, normalized_image_path)
                # Ensure the path exists before creating the clip
                if not os.path.isfile(image_path):
                    flash(f"File not found: {image_path}", "danger")
                    continue  # Skip this image
                image_clip = ImageClip(image_path, duration=duration).resize(newsize=resolution)  # Set the size here
                image_clips.append(image_clip)

            if not image_clips:
                flash('No images were selected for the video.', 'danger')
                return redirect(url_for('create'))
            
            video_clip = concatenate_videoclips(image_clips, method='compose')
            # Fetch and set the audio
            audio_clip = None
            if selected_audio_id:
                with connection.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
                    cursor.execute('SELECT audio_path FROM audio_library WHERE audio_id = %s', (selected_audio_id,))
                    audio_record = cursor.fetchone()
                if audio_record:
                    # Correct the audio_file_path by removing the './' and replacing backslashes with forward slashes
                    #audio_file_path = os.path.join(app.static_folder, audio_record['audio_path'])  # Full path to the audio
                    clean_audio_path = audio_record['audio_path'].lstrip('./').replace('\\', '/')
                    if clean_audio_path.startswith('static/'):
                        clean_audio_path = clean_audio_path[len('static/'):]
        
                        # Combine the clean path with the static folder path
                        audio_file_path = os.path.join(app.static_folder, clean_audio_path)
                    try:
                        audio_clip = AudioFileClip(audio_file_path)
                        # Set the audio to the video if audio is selected
                        video_clip.audio = audio_clip.set_duration(video_clip.duration)
                    except IOError as e:
                        print(f"Error loading audio file: {e}")
                        flash(f'Error loading audio file: {e}', 'danger')

            # Set the audio to the video if audio is selected
            if audio_clip:
                video_clip.audio = audio_clip

            # Define directory for saving the video
            videos_folder = os.path.join(app.static_folder, 'videos')
            if not os.path.exists(videos_folder):
                os.makedirs(videos_folder)

            output_video_path = os.path.join('videos', secure_filename(f'video_{user_id}_{video_title}.mp4'))
            full_output_video_path = os.path.join(app.static_folder, output_video_path)
            
            # Write the video file without the 'size' argument
            video_clip.write_videofile(full_output_video_path, fps=24, codec='libx264', bitrate=quality, audio_codec='aac', preset='medium')
            video_path = f"videos/video_{user_id}_{video_title}.mp4"

            flash('Video created successfully!', 'success')
        except Exception as e:
            flash(f'Error creating video: {e}', 'danger')
            app.logger.error(f'Exception on /create [POST]: {e}', exc_info=True)
            video_path = None 

        # Redirect to the same page to show the form and the result
        return render_template('home/create.html', form=form, images=images, audio_files=audio_files, video_path=video_path)
    
    # Close the cursor for the GET request
    # cursor.close()
    # If it's a GET request or the form isn't validated, render the template normally
    return render_template('home/create.html', form=form, images=images, audio_files=audio_files, video_path=output_video_path)

@app.route('/download_video/<path:video_filename>')
def download_video(video_filename):
    #flash('Your download will begin shortly.', 'info')
    directory = os.path.join(app.static_folder, 'videos')
    response = send_from_directory(directory=directory, path=video_filename, as_attachment=True)
    response.headers["Content-Disposition"] = f"attachment; filename={video_filename}"
    return response

@app.route('/logout')
def logout():
    # Remove session data, this will log the user out
    session.pop('loggedin', None)
    session.pop('id', None)
    session.pop('username', None)
    session.pop('jwt_token', None)
    # Redirect to login page
    return redirect(url_for('login'))

if __name__ =='__main__':
    app.run(debug=True)
