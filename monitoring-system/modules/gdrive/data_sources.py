#!/usr/bin/env python3
"""
データソース管理モジュール
Google Driveにアップロードするデータの生成・管理を担当
"""

import random
from datetime import datetime
from typing import Dict, Any

class DataSource:
    """データソース管理クラス（IoT拡張対応）"""
    
    @staticmethod
    def create_test_data() -> Dict[str, Any]:
        """テスト用ランダムデータ生成"""
        return {
            "data_type": "test",
            "device_id": "test_device_001",
            "timestamp": datetime.now().isoformat(),
            "test_value": random.randint(1, 100),
            "temperature": round(random.uniform(15.0, 35.0), 1),
            "humidity": round(random.uniform(30.0, 80.0), 1),
            "status": "test_ok",
            "battery_level": random.randint(20, 100)
        }
    
    @staticmethod
    def create_network_data(network_data: Dict[str, Any]) -> Dict[str, Any]:
        """ネットワーク監視データを整形"""
        data = network_data.copy()
        data.update({
            "data_type": "network_monitoring",
            "timestamp": datetime.now().isoformat(),
            "source": "raspi_network_monitor"
        })
        return data
    
    @staticmethod
    def get_filename(data_type: str) -> str:
        """ファイル名生成"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{data_type}_{timestamp}.json"

class IoTDataSource:
    """IoTセンサーデータソース（将来実装）"""
    
    @staticmethod
    def create_temperature_data() -> Dict[str, Any]:
        """温度センサーデータ（将来実装）"""
        return {
            "data_type": "temperature_sensor",
            "sensor_id": "temp_001",
            "timestamp": datetime.now().isoformat(),
            "temperature": 25.5,  # 実際のセンサーから取得
            "location": "room_a"
        }
    
    @staticmethod
    def create_humidity_data() -> Dict[str, Any]:
        """湿度センサーデータ（将来実装）"""
        return {
            "data_type": "humidity_sensor", 
            "sensor_id": "humid_001",
            "timestamp": datetime.now().isoformat(),
            "humidity": 60.0,  # 実際のセンサーから取得
            "location": "room_a"
        }
    
    @staticmethod
    def create_motion_data() -> Dict[str, Any]:
        """モーションセンサーデータ（将来実装）"""
        return {
            "data_type": "motion_sensor",
            "sensor_id": "motion_001", 
            "timestamp": datetime.now().isoformat(),
            "motion_detected": True,
            "location": "entrance"
        }
    
    @staticmethod
    def create_light_data() -> Dict[str, Any]:
        """照度センサーデータ（将来実装）"""
        return {
            "data_type": "light_sensor",
            "sensor_id": "light_001",
            "timestamp": datetime.now().isoformat(),
            "luminance": 450.0,  # lux
            "location": "window_side"
        }

class RecordingDataSource:
    """録音データソース"""
    
    @staticmethod
    def create_recording_metadata(filename: str, duration: float, device_info: Dict[str, Any]) -> Dict[str, Any]:
        """録音ファイルのメタデータ生成"""
        return {
            "data_type": "audio_recording",
            "filename": filename,
            "timestamp": datetime.now().isoformat(),
            "duration_seconds": duration,
            "device_info": device_info,
            "file_size_bytes": 0,  # 実際のファイルサイズで更新
            "format": "wav",
            "sample_rate": device_info.get("sample_rate", 44100),
            "channels": device_info.get("channels", 1)
        }
