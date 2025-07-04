#!/usr/bin/env python3
"""
USB接続機器検出関数の例
カメラ、マイク、GPS等のUSB機器を検出
"""

import subprocess
import re
from typing import List, Dict, Any

def get_usb_devices() -> List[Dict[str, Any]]:
    """USB接続機器の一覧取得"""
    try:
        devices = []
        
        # lsusb コマンドでUSB機器一覧取得
        result = subprocess.run(['lsusb'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            for line in lines:
                # Bus 001 Device 003: ID 1234:5678 Company Name Product Name
                match = re.match(r'Bus (\d+) Device (\d+): ID ([0-9a-f]{4}):([0-9a-f]{4}) (.*)', line, re.IGNORECASE)
                if match:
                    bus, device, vendor_id, product_id, description = match.groups()
                    
                    # デバイスタイプの推定
                    device_type = classify_usb_device(description, vendor_id, product_id)
                    
                    devices.append({
                        'bus': int(bus),
                        'device': int(device),
                        'vendor_id': vendor_id,
                        'product_id': product_id,
                        'description': description.strip(),
                        'device_type': device_type,
                        'method': 'usb'
                    })
        
        return devices
        
    except Exception as e:
        print(f"USB devices scan error: {e}")
        return []

def classify_usb_device(description: str, vendor_id: str, product_id: str) -> str:
    """USB機器のタイプを分類"""
    desc_lower = description.lower()
    
    # カメラ関連
    if any(keyword in desc_lower for keyword in ['camera', 'webcam', 'video', 'uvc']):
        return 'カメラ'
    
    # マイク関連
    if any(keyword in desc_lower for keyword in ['microphone', 'mic', 'audio', 'sound']):
        return 'マイク'
    
    # GPS関連
    if any(keyword in desc_lower for keyword in ['gps', 'gnss', 'navigation', 'garmin']):
        return 'GPS'
    
    # ストレージ
    if any(keyword in desc_lower for keyword in ['storage', 'disk', 'flash', 'mass storage']):
        return 'ストレージ'
    
    # 入力機器
    if any(keyword in desc_lower for keyword in ['mouse', 'keyboard', 'hid']):
        return '入力機器'
    
    # ネットワーク
    if any(keyword in desc_lower for keyword in ['ethernet', 'wifi', 'wireless', 'network']):
        return 'ネットワーク'
    
    # Bluetooth
    if any(keyword in desc_lower for keyword in ['bluetooth', 'bt']):
        return 'Bluetooth'
    
    return 'その他'

# 使用例
if __name__ == "__main__":
    devices = get_usb_devices()
    for device in devices:
        print(f"{device['device_type']}: {device['description']}")
