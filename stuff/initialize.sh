python -m pip install -r requirements_freeze.txt
export FLASK_APP=main.py
export FLASK_DEBUG=1 
curl --create-dirs -o ./.postgresql/root.crt 'https://cockroachlabs.cloud/clusters/65f68c43-5041-4a45-a4ac-c1b1f638f36a/cert'
