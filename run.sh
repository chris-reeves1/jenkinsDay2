#!/bin/bash
exec python -m gunicorn -b 0.0.0.0:5500 app:app 

# app:app = app.py flask app - ie run the app inside app.py
#-b 0.0.0.0 = all ips on port 5500
# python -m gunicorn - runs the guni module
# exec = kinda creates a new shell to run in 