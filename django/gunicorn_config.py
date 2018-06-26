import os

bind = '0.0.0.0:8000'

reload = True

site_id = int(os.getenv('SITE_ID', '0'))
accesslog = f'/web_server_logs/gunicorn_logs/{site_id}-access.log'
errorlog = f'/web_server_logs/gunicorn_logs/{site_id}-error.log'