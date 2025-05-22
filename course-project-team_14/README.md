# Team 14

**Members:**  
- Keerthana Korlapati  
- Vishaka Agrawal  
- Priyanshi Gupta  
- Sachi Thonse Rao  

---

## Paths:
1. Accessible paths are given as input when initializing the storage server.
2. All paths dealt with here, including input paths given by the client, are absolute.
3. If a directory is mentioned as an accessibe path, all the files/directories inside it would be included.
4. All files are named as `<name>.txt`
5. All mp3 files are named as `<name>.mp3`

---

## How to Run:
- Do `make` first.
- For running the naming server, just do `./nm`
- For running the storage server, `./ss <naming_server_ip> <naming_port> <client_port>`
- For running the client, `./cl <naming_server_ip> <naming_port>`

---

## CREATE:
**Format:** `CREATE <destination_path> <file/folder_name>`  
This creates the a file/folder with the given name in the given destination folder.

---

## DELETE:
**Format:** `DELETE <path>`  
Deletes the file/folder whose path is given. In case it is a folder, its contents are also deleted.

---

## COPY:
**Format:** `COPY <src_path> <dest_path>`  
- If src is a file and dest is a file, the contents of the source file are copied to the destination file.
- If src is a file and dest is folder, then the file is created and filled with its content in the dest folder.
- If src is a folder and dest is a folder, then the src folder along with its contents are created in the dest folder.
- Any other combination of src and dest will give an error.

---

## READ:
**Format:** `READ <path>`  
This prints the contents of the file. If it is not file, an error is given.

---

## WRITE:
**Format:** `WRITE <path> <data>`  
This appends the data into the file whose path is given. If it is not file, an error is given.  
- The write happends asyncronoulsy if the data is above a certain limit. To prioritise asynchronous write, this is the format:  
  `WRITE <path> --SYNC <data>`

---

## STREAM:
**Format:** `STREAM <path>`  
This streams the mp3 directed by the path given. If it's not an mp3, it gives an error.  
The client can Pause, Resume and quit while streaming.

---

## GET_INFO:
**Format:** `GET_INFO <path>`  
This gives the info like Size, Permissions and last modified.

---

## GET_PATHS:
**Format:** `GET_PATHS (following with a space)`  
This gives a list of all accessible paths accross all storage servers.

---

## LIST_DIR:
**Format:** `LIST_DIR <path>`  
This gives a list of contents that is inside the folder indicated by the path. If it is not a folder, gives an error.

---

## NOTE:
1. Book-keeping is done for the naming server. It can be viewed in the `naming_server.log` text file that is created with the naming server is run.
2. Server failure is detected only when the server goes doen with `SIGINT`(Ctrl+C) signal.
