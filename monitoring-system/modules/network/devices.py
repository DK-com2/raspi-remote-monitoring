"""
デバイス検出モジュール
カメラ、マイク、GPSデバイスの検出を担当
"""

import subprocess
import re
import glob
import os
from typing import List, Dict, Any
from datetime import datetime

class DeviceDetector:
    """デバイス検出クラス"""
    
    def __init__(self):
        self.devices = []
    
    def scan_all_devices(self) -> List[Dict[str, Any]]:
        """USB接続デバイスのスキャン"""
        try:
            devices = []
            
            # lsusb コマンドでUSBデバイス一覧を取得
            try:
                result = subprocess.run(['lsusb'], capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    
                    for line in lines:
                        if line.strip():
                            device_info = self.parse_lsusb_line(line)
                            if device_info:
                                devices.append(device_info)
                
            except FileNotFoundError:
                print("lsusb command not found - installing usbutils may be required")
                devices = self.fallback_usb_detection()
            except Exception as e:
                print(f"lsusb execution error: {e}")
                devices = self.fallback_usb_detection()
            
            self.devices = devices
            return devices
            
        except Exception as e:
            print(f"USB device scan error: {e}")
            return []
    
    def parse_lsusb_line(self, line: str) -> Dict[str, Any]:
        """lsusb出力行を解析"""
        try:
            # Bus 001 Device 003: ID 1234:5678 Company Product Name
            match = re.match(r'Bus\s+(\d+)\s+Device\s+(\d+):\s+ID\s+([0-9a-f]{4}):([0-9a-f]{4})\s+(.*)', line, re.IGNORECASE)
            
            if match:
                bus, device, vendor_id, product_id, description = match.groups()
                
                return {
                    'id': f"usb-{vendor_id.upper()}-{product_id.upper()}-{bus}-{device}",
                    'name': description.strip(),
                    'type': self.classify_device_type(description),
                    'status': 'connected',
                    'device_path': f'/dev/bus/usb/{bus.zfill(3)}/{device.zfill(3)}',
                    'vendor_id': vendor_id.upper(),
                    'product_id': product_id.upper(),
                    'bus': bus,
                    'device': device,
                    'manufacturer': self.get_manufacturer_name(vendor_id.upper()),
                    'last_seen': datetime.now().strftime('%Y/%m/%d %H:%M:%S'),
                    'connection_type': 'USB',
                    'hostname': '-',
                    'mac': 'Unknown',
                    'ip': '-'
                }
            
            return None
            
        except Exception as e:
            print(f"lsusb line parse error: {e}")
            return None
    
    def classify_device_type(self, description: str) -> str:
        """デバイスタイプの分類"""
        desc_lower = description.lower()
        
        # オーディオデバイス
        if any(keyword in desc_lower for keyword in ['audio', 'sound', 'microphone', 'mic', 'speaker', 'headset']):
            return 'オーディオ'
        
        # カメラ・映像デバイス
        if any(keyword in desc_lower for keyword in ['camera', 'webcam', 'video', 'capture']):
            return 'カメラ'
        
        # ストレージデバイス
        if any(keyword in desc_lower for keyword in ['storage', 'disk', 'drive', 'flash', 'mass storage']):
            return 'ストレージ'
        
        # 入力デバイス
        if any(keyword in desc_lower for keyword in ['keyboard', 'mouse', 'joystick', 'gamepad', 'hid']):
            return '入力デバイス'
        
        # ネットワークデバイス
        if any(keyword in desc_lower for keyword in ['network', 'ethernet', 'wifi', 'wireless', 'bluetooth']):
            return 'ネットワーク'
        
        return 'その他'
    
    def get_manufacturer_name(self, vendor_id: str) -> str:
        """ベンダーIDから製造元名を取得"""
        vendor_names = {
            '1D6B': 'Linux Foundation',
            '046D': 'Logitech',
            '0781': 'SanDisk',
            '0BDA': 'Realtek',
            '05AC': 'Apple',
            '04E8': 'Samsung',
            '0424': 'Microchip Technology',
            '05E3': 'Genesys Logic'
        }
        return vendor_names.get(vendor_id, 'Unknown')
    
    def fallback_usb_detection(self) -> List[Dict[str, Any]]:
        """lsusbが使用できない場合のフォールバック検出"""
        try:
            devices = []
            usb_devices_path = '/sys/bus/usb/devices'
            
            if os.path.exists(usb_devices_path):
                for device_dir in os.listdir(usb_devices_path):
                    if '-' in device_dir and '.' in device_dir:
                        device_path = os.path.join(usb_devices_path, device_dir)
                        try:
                            vendor_path = os.path.join(device_path, 'idVendor')
                            product_path = os.path.join(device_path, 'idProduct')
                            
                            if os.path.exists(vendor_path) and os.path.exists(product_path):
                                with open(vendor_path, 'r') as f:
                                    vendor_id = f.read().strip().upper()
                                with open(product_path, 'r') as f:
                                    product_id = f.read().strip().upper()
                                
                                devices.append({
                                    'id': f'usb-sys-{vendor_id}-{product_id}-{device_dir}',
                                    'name': f'USB Device {device_dir}',
                                    'type': 'その他',
                                    'status': 'connected',
                                    'device_path': device_path,
                                    'vendor_id': vendor_id,
                                    'product_id': product_id,
                                    'manufacturer': self.get_manufacturer_name(vendor_id),
                                    'last_seen': datetime.now().strftime('%Y/%m/%d %H:%M:%S'),
                                    'connection_type': 'USB',
                                    'hostname': '-',
                                    'mac': 'Unknown',
                                    'ip': '-'
                                })
                        except Exception as e:
                            continue
            
            return devices
        except Exception as e:
            print(f"Fallback USB detection error: {e}")
            return []

    def scan_camera_devices(self) -> List[Dict[str, Any]]:
        """カメラデバイスの検出"""
        try:
            devices = []
            
            # Video4Linux (V4L2) デバイスの検出
            try:
                video_devices = glob.glob('/dev/video*')
                for device_path in video_devices:
                    try:
                        # v4l2-ctlでデバイス情報取得
                        result = subprocess.run(['v4l2-ctl', '--device', device_path, '--info'], 
                                              capture_output=True, text=True, timeout=5)
                        if result.returncode == 0:
                            # デバイス名を抽出
                            name_match = re.search(r'Card type\s*:\s*(.+)', result.stdout)
                            device_name = name_match.group(1).strip() if name_match else f'Camera {device_path}'
                            
                            # ドライバー情報を抽出
                            driver_match = re.search(r'Driver name\s*:\s*(.+)', result.stdout)
                            driver = driver_match.group(1).strip() if driver_match else 'unknown'
                            
                            devices.append({
                                'device_path': device_path,
                                'name': device_name,
                                'type': 'カメラ',
                                'driver': driver,
                                'status': 'available',
                                'method': 'v4l2'
                            })
                    except Exception as e:
                        # v4l2-ctlが失敗してもデバイスは表示
                        devices.append({
                            'device_path': device_path,
                            'name': f'Camera {device_path}',
                            'type': 'カメラ',
                            'driver': 'unknown',
                            'status': 'detected',
                            'method': 'filesystem'
                        })
            except Exception as e:
                print(f"Camera detection error: {e}")
            
            return devices
            
        except Exception as e:
            print(f"Camera devices scan error: {e}")
            return []
    
    def scan_audio_devices(self) -> List[Dict[str, Any]]:
        """オーディオデバイス（マイク）の検出"""
        try:
            devices = []
            
            # ALSA録音デバイスの検出
            try:
                result = subprocess.run(['arecord', '-l'], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    lines = result.stdout.split('\n')
                    for line in lines:
                        # 日本語版と英語版の両方に対応
                        match = re.match(r'カード\s+(\d+):\s+([^\[]+)\s*\[([^\]]+)\].*デバイス\s+(\d+):\s*([^\[]+)\s*\[([^\]]+)\]', line)
                        if not match:
                            match = re.match(r'card\s+(\d+):\s+([^\[]+)\s*\[([^\]]+)\].*device\s+(\d+):\s*([^\[]+)\s*\[([^\]]+)\]', line, re.IGNORECASE)
                        
                        if match:
                            card_num, card_name, card_desc, device_num, device_name, device_desc = match.groups()
                            devices.append({
                                'device_path': f'/dev/snd/pcmC{card_num}D{device_num}c',
                                'name': f'{device_desc.strip()}',
                                'type': 'マイク',
                                'card': f'Card {card_num}',
                                'device': f'Device {device_num}',
                                'status': 'available',
                                'method': 'alsa'
                            })
            except FileNotFoundError:
                print("arecord command not found")
            except Exception as e:
                print(f"Audio device detection error: {e}")
            
            # PulseAudioデバイスの検出（バックアップ）
            if not devices:
                try:
                    result = subprocess.run(['pactl', 'list', 'short', 'sources'], 
                                          capture_output=True, text=True, timeout=5)
                    if result.returncode == 0:
                        lines = result.stdout.strip().split('\n')
                        for line in lines:
                            if line.strip():
                                parts = line.split('\t')
                                if len(parts) >= 2:
                                    source_name = parts[1]
                                    if 'monitor' not in source_name.lower():  # モニターソースを除外
                                        devices.append({
                                            'device_path': source_name,
                                            'name': source_name.replace('alsa_input.', '').replace('_', ' '),
                                            'type': 'マイク',
                                            'status': 'available',
                                            'method': 'pulseaudio'
                                        })
                except FileNotFoundError:
                    print("pactl command not found")
                except Exception as e:
                    print(f"PulseAudio device detection error: {e}")
            
            return devices
            
        except Exception as e:
            print(f"Audio devices scan error: {e}")
            return []
    
    def scan_gps_devices(self) -> List[Dict[str, Any]]:
        """GPSデバイスの検出"""
        try:
            devices = []
            
            # USB GPSデバイスの検出
            try:
                result = subprocess.run(['lsusb'], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    lines = result.stdout.split('\n')
                    for line in lines:
                        line_lower = line.lower()
                        if any(keyword in line_lower for keyword in ['gps', 'gnss', 'navigation', 'garmin', 'u-blox']):
                            # Bus 001 Device 003: ID 1234:5678 Company GPS Device
                            match = re.match(r'Bus\s+(\d+)\s+Device\s+(\d+):\s+ID\s+([0-9a-f]{4}):([0-9a-f]{4})\s+(.*)', line, re.IGNORECASE)
                            if match:
                                bus, device, vendor_id, product_id, description = match.groups()
                                devices.append({
                                    'device_path': f'/dev/bus/usb/{bus.zfill(3)}/{device.zfill(3)}',
                                    'name': description.strip(),
                                    'type': 'GPS',
                                    'vendor_id': vendor_id,
                                    'product_id': product_id,
                                    'status': 'connected',
                                    'method': 'usb'
                                })
            except FileNotFoundError:
                print("lsusb command not found")
            except Exception as e:
                print(f"USB GPS detection error: {e}")
            
            # シリアルGPSデバイスの検出
            try:
                # 一般的なGPSデバイスパス
                gps_paths = (glob.glob('/dev/ttyUSB*') + 
                            glob.glob('/dev/ttyACM*') + 
                            glob.glob('/dev/serial/by-id/*GPS*') + 
                            glob.glob('/dev/serial/by-id/*gps*'))
                
                for device_path in gps_paths:
                    try:
                        # デバイスの存在確認
                        if os.path.exists(device_path):
                            device_name = os.path.basename(device_path)
                            devices.append({
                                'device_path': device_path,
                                'name': f'Serial GPS ({device_name})',
                                'type': 'GPS',
                                'status': 'detected',
                                'method': 'serial'
                            })
                    except Exception as e:
                        print(f"Serial GPS check error for {device_path}: {e}")
            except Exception as e:
                print(f"Serial GPS detection error: {e}")
            
            return devices
            
        except Exception as e:
            print(f"GPS devices scan error: {e}")
            return []
    
    def get_devices_by_type(self, device_type: str) -> List[Dict[str, Any]]:
        """タイプ別デバイス取得"""
        return [device for device in self.devices if device.get('type') == device_type]
    
    def get_device_count(self) -> Dict[str, int]:
        """デバイス数の統計"""
        counts = {}
        for device in self.devices:
            device_type = device.get('type', 'unknown')
            counts[device_type] = counts.get(device_type, 0) + 1
        return counts
    
    def test_device_availability(self, device_path: str) -> bool:
        """デバイスの利用可能性テスト"""
        try:
            return os.path.exists(device_path)
        except Exception:
            return False
