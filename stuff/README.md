# Flask Image & Audio Upload App – Setup Guide

This guide will walk you through setting up a Flask application that handles image and audio uploads, along with configuring its MySQL database.

---

## Python Virtual Environment Setup

To begin, create and activate a Python virtual environment:

```bash
py -3 -m venv venv
venv\Scripts\activate
```
## Install Requirements
After activating your virtual environment, install the project dependencies:

```bash
python -m pip install -r requirements.txt
```
Additionally, manually install any other modules not listed in requirements.txt.

## MySQL Database Setup
Create Database and Tables
First, create the loginapp database and then switch to it:

```bash
CREATE DATABASE loginapp;
USE loginapp;
```
Next, create the necessary tables:

```bash
-- Create 'accounts' table with id, username, email, and password columns.
CREATE TABLE accounts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL
);

-- Create 'images' table for storing image data.
CREATE TABLE IF NOT EXISTS images (
  image_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  image_name VARCHAR(255) NOT NULL,
  image_path VARCHAR(255) NOT NULL,
  image BLOB,
  metadata TEXT
);

-- Create 'audio_library' table for storing audio files.
CREATE TABLE IF NOT EXISTS audio_library (
  audio_id INT AUTO_INCREMENT PRIMARY KEY,
  audio_name VARCHAR(255) NOT NULL, -- Name of the audio file
  audio_blob MEDIUMBLOB NOT NULL, -- Storing the audio as binary data
  audio_path VARCHAR(255), -- Path to the audio file on the server, if applicable
  metadata TEXT, -- Any additional data you want to store about the audio file
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp of when the audio was uploaded
);
```
Debugging Query: Delete Image by User ID
You can use this command to delete images associated with a specific user, which can be helpful for debugging:

```bash
DELETE FROM images WHERE user_id = 1;
```

## Flask Application Configuration
In your main.py file, ensure your MySQL connection details are accurate. Modify the app.config values to match your MySQL server's settings, especially the password:

```bash
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = 'yourMYSQL password' # Example: 'computing@123!'
app.config['MYSQL_DB'] = 'loginapp'
```

## Running the Application
Navigate to your project's root directory (where main.py is located) and execute the following commands in PowerShell:

```bash
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
set FLASK_APP=main.py
set FLASK_DEBUG=1
flask --app main.py run
```
Alternatively, you can use the PowerShell shorthand:
```bash
$env:FLASK_APP="main.py"
$env:FLASK_DEBUG = "1"
flask run
```
If you prefer to run without a virtual environment (though not recommended for development):

```bash
python -m flask --app main.py run
```
## Verifying Database Entries
Check Accounts Table
To see if new accounts are being added to the accounts table:

```bash
SELECT * FROM accounts;
```

## Check Image Uploads
Since image data is stored as BLOBs (Binary Large Objects) and won't be readable directly with a SELECT * command, use these queries to verify uploads:

```bash
SELECT COUNT(*) FROM images WHERE user_id=1;
SELECT image_id, LENGTH(image) AS image_size FROM images WHERE user_id=1;
```
If images aren't updating, you might need to manually insert a test image using a command similar to the following (replace with your actual image data and path):

```bash
-- Example: INSERT INTO images (user_id, image_name, image_path, image) VALUES (1, 'test_image.jpg', '/path/to/test_image.jpg', LOAD_FILE('/path/to/your/image.jpg'));
```
## Useful SQL Queries
Here are some additional SQL queries to help you inspect and manage your database:
```bash
1. Details of All Users
SELECT * FROM accounts;
2. Number of Images Per User
SELECT
  accounts.username,
  COUNT(images.image_id) AS number_of_images
FROM
  accounts
JOIN
  images ON accounts.id = images.user_id
GROUP BY
  accounts.username;
3. Length of Image Paths Per User
SELECT
  accounts.username,
  images.image_path,
  CHAR_LENGTH(images.image_path) AS path_length
FROM
  accounts
JOIN
  images ON accounts.id = images.user_id;
4. Comprehensive Information Per User
SELECT
  accounts.id,
  accounts.username,
  accounts.email,
  COUNT(images.image_id) AS number_of_images,
  AVG(CHAR_LENGTH(images.image_path)) AS avg_path_length
FROM
  accounts
LEFT JOIN
  images ON accounts.id = images.user_id
GROUP BY
  accounts.id;
5. Displaying Binary Image Data Size
SELECT
  accounts.username,
  images.image_id,
  OCTET_LENGTH(images.image) AS image_size_in_bytes
FROM
  accounts
JOIN
  images ON accounts.id = images.user_id;
6. Display Data for Audio Library
SELECT audio_id, audio_name, OCTET_LENGTH(audio_blob) AS blob_length, audio_path, metadata, uploaded_at
```