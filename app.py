import os
import sys
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from urllib.parse import quote_plus
from flask import Flask
from flask_cors import CORS 
from dotenv import load_dotenv
from flasgger import Swagger
import asyncio

load_dotenv()

from services.extensions import r, init_robot_status

# 라우트 임포트
from routes.order import bp as order_bp
from routes.stock import bp as stock_bp

def create_app():
    app = Flask(__name__)
    app.json.ensure_ascii = False
    
    # CORS 설정
    CORS(app, resources={r"*": {"origins": "*"}}) 

    swagger_config = {
        "headers": [],
        "specs": [
            {
                "endpoint": 'apispec_1',
                "route": '/apispec_1.json',
                "rule_filter": lambda rule: True,
                "model_filter": lambda tag: True,
            }
        ],
        "static_url_path": "/flasgger_static",
        "swagger_ui": True,
        "specs_route": "/apidocs/"
    }

    template = {
        "swagger": "2.0",
        "info": {
            "title": "SJIOT Keycap Order API",
            "description": "키캡 주문/상태 조회 API",
            "version": "1.0.0"
        },
        "basePath": "/",
        "schemes": ["https"],
    }

    swagger = Swagger(app, config=swagger_config, template=template)
    
    app.config['JSON_AS_ASCII'] = False 

    init_robot_status()
    
    # 블루프린트 등록
    app.register_blueprint(order_bp)
    app.register_blueprint(stock_bp)

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True)