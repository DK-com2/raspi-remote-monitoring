#!/usr/bin/env python3
"""
ネットワーク通信強度監視アプリ
遠隔操作のための第一歩として、ネットワーク状態をリアルタイム監視
"""

from flask import Flask, render_template, jsonify, request
import subprocess
import re
import time
import threading
import psutil
import requests
from datetime import datetime

# Google Drive連携機能
from gdrive_utils import GDriveManager, DataSource

app = Flask(__name__)

# グローバル変数（ネットワーク状態保存用）
network_data = {
    'last_update': None,
    'ping_latency': None,
    'internet_speed': None,
    'connection_status': 'checking',
    'network_interfaces': [],
    'tailscale_status': 'unknown',
    'tailscale_ip': None,
    'connected_devices': []  # 接続機器一覧
}

# Google Drive用グローバル変数
gdrive_data = {
    'connection_status': 'not_configured',
    'last_check': None,
    'user_email': None,
    'last_upload': None,
    'message': '未設定'
}

# Google Drive初期化
try:
    gdrive_manager = GDriveManager()
    print("Google Drive manager initialized")
except Exception as e:
    print(f"Google Drive initialization failed: {e}")
    gdrive_manager = None

def get_connection_type():
    """接続タイプの判定（WiFi/モバイル/有線）"""
    try:
        # ネットワークインターフェースから接続タイプを判定
        interfaces = psutil.net_if_addrs()
        
        for interface_name, addresses in interfaces.items():
            if_stats = psutil.net_if_stats().get(interface_name)
            if if_stats and if_stats.isup:
                # WiFi インターフェース
                if any(name in interface_name.lower() for name in ['wlan', 'wifi', 'wl']):
                    return 'wifi', interface_name
                # モバイル/cellular インターフェース
                elif any(name in interface_name.lower() for name in ['wwan', 'ppp', 'usb', 'rmnet', 'qmi']):
                    return 'mobile', interface_name
                # 有線イーサネット
                elif any(name in interface_name.lower() for name in ['eth', 'en']):
                    return 'ethernet', interface_name
        
        return 'unknown', None
        
    except Exception as e:
        print(f"Connection type detection error: {e}")
        return 'unknown', None

def get_connected_devices():
    """接続されているデバイスの一覧取得（マイク、カメラ、GPS特化）"""
    try:
        devices = []
        
        # カメラデバイスの検出
        camera_devices = get_camera_devices()
        devices.extend(camera_devices)
        
        # オーディオデバイス（マイク）の検出
        audio_devices = get_audio_devices()
        devices.extend(audio_devices)
        
        # GPSデバイスの検出
        gps_devices = get_gps_devices()
        devices.extend(gps_devices)
        
        return devices
        
    except Exception as e:
        print(f"Connected devices scan error: {e}")
        return []

def get_camera_devices():
    """カメラデバイスの検出"""
    try:
        devices = []
        
        # Video4Linux (V4L2) デバイスの検出
        try:
            import glob
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

def get_audio_devices():
    """オーディオデバイス（マイク）の検出"""
    try:
        devices = []
        
        # ALSA録音デバイスの検出
        try:
            result = subprocess.run(['arecord', '-l'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    # カード 0: bcm2835 [bcm2835 ALSA], デバイス 0: bcm2835 ALSA [bcm2835 ALSA]
                    match = re.match(r'カード\s+(\d+):\s+([^\[]+)\s*\[([^\]]+)\].*デバイス\s+(\d+):\s*([^\[]+)\s*\[([^\]]+)\]', line)
                    if not match:
                        # 英語版もチェック
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

def get_gps_devices():
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
            import glob
            # 一般的なGPSデバイスパス
            gps_paths = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*') + glob.glob('/dev/serial/by-id/*GPS*') + glob.glob('/dev/serial/by-id/*gps*')
            
            for device_path in gps_paths:
                try:
                    # デバイスの存在確認
                    import os
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

def get_wifi_signal_strength():
    try:
        # 方法1: iwconfig コマンド
        try:
            result = subprocess.run(['iwconfig'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                output = result.stdout
                
                # 信号強度とSSIDを抽出
                signal_match = re.search(r'Signal level=(-\d+)', output)
                ssid_match = re.search(r'ESSID:"([^"]*)"', output)
                
                signal_strength = None
                ssid = None
                signal_dbm = None
                
                if signal_match:
                    signal_dbm = int(signal_match.group(1))
                    # dBmを％に変換（概算）
                    if signal_dbm >= -50:
                        signal_strength = 100
                    elif signal_dbm >= -60:
                        signal_strength = 80
                    elif signal_dbm >= -70:
                        signal_strength = 60
                    elif signal_dbm >= -80:
                        signal_strength = 40
                    else:
                        signal_strength = 20
                        
                if ssid_match:
                    ssid = ssid_match.group(1)
                    
                return signal_strength, ssid, signal_dbm
                
        except FileNotFoundError:
            print("iwconfig not found, trying alternative methods...")
        
        # 方法2: nmcli コマンド（NetworkManager）
        try:
            result = subprocess.run(['nmcli', '-t', '-f', 'active,ssid,signal', 'dev', 'wifi'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    if line.startswith('yes:'):
                        parts = line.split(':')
                        if len(parts) >= 3:
                            ssid = parts[1]
                            signal = parts[2]
                            if signal and signal.isdigit():
                                return int(signal), ssid, None
        except FileNotFoundError:
            print("nmcli not found")
        
        # 方法3: /proc/net/wireless ファイル読み取り
        try:
            with open('/proc/net/wireless', 'r') as f:
                lines = f.readlines()
                if len(lines) > 2:  # ヘッダー行をスキップ
                    for line in lines[2:]:
                        parts = line.split()
                        if len(parts) >= 4:
                            interface = parts[0].rstrip(':')
                            link_quality = parts[2]  # リンク品質
                            if '/' in link_quality:
                                current, max_val = link_quality.split('/')
                                if current.isdigit() and max_val.isdigit():
                                    signal_strength = int((int(current) / int(max_val)) * 100)
                                    return signal_strength, f"WiFi-{interface}", None
        except (FileNotFoundError, IOError, ValueError):
            print("/proc/net/wireless not available")
        
        # 方法4: iw コマンド
        try:
            # アクティブなワイヤレスインターフェースを取得
            result = subprocess.run(['iw', 'dev'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                interface_match = re.search(r'Interface (\w+)', result.stdout)
                if interface_match:
                    interface = interface_match.group(1)
                    
                    # 接続情報を取得
                    link_result = subprocess.run(['iw', interface, 'link'], 
                                                capture_output=True, text=True, timeout=5)
                    if link_result.returncode == 0:
                        ssid_match = re.search(r'SSID: (.*)', link_result.stdout)
                        signal_match = re.search(r'signal: (-\d+)', link_result.stdout)
                        
                        ssid = ssid_match.group(1) if ssid_match else None
                        signal_dbm = int(signal_match.group(1)) if signal_match else None
                        
                        if signal_dbm:
                            # dBmを％に変換
                            if signal_dbm >= -50:
                                signal_strength = 100
                            elif signal_dbm >= -60:
                                signal_strength = 80
                            elif signal_dbm >= -70:
                                signal_strength = 60
                            elif signal_dbm >= -80:
                                signal_strength = 40
                            else:
                                signal_strength = 20
                            
                            return signal_strength, ssid, signal_dbm
        except FileNotFoundError:
            print("iw command not found")
        
        # すべての方法が失敗した場合
        print("No WiFi information method available")
        return None, "WiFi情報取得不可", None
        
    except Exception as e:
        print(f"WiFi info error: {e}")
        return None, "エラー", None

def ping_test(host='8.8.8.8', count=3):
    """Ping レイテンシテスト"""
    try:
        result = subprocess.run(
            ['ping', '-c', str(count), host], 
            capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0:
            # 平均レイテンシを抽出
            match = re.search(r'rtt min/avg/max/mdev = [\d.]+/([\d.]+)', result.stdout)
            if match:
                return float(match.group(1))
        return None
        
    except Exception as e:
        print(f"Ping error: {e}")
        return None

def internet_speed_test():
    """簡易インターネット速度テスト"""
    try:
        # 小さなファイルをダウンロードして速度測定
        start_time = time.time()
        response = requests.get('http://httpbin.org/bytes/1048576', timeout=10)  # 1MB
        end_time = time.time()
        
        if response.status_code == 200:
            duration = end_time - start_time
            size_mb = len(response.content) / (1024 * 1024)
            speed_mbps = (size_mb * 8) / duration  # Mbps
            return round(speed_mbps, 2)
            
    except Exception as e:
        print(f"Speed test error: {e}")
        
    return None

def get_network_interfaces():
    """ネットワークインターフェース情報取得"""
    try:
        interfaces = []
        for interface, addrs in psutil.net_if_addrs().items():
            if_stats = psutil.net_if_stats().get(interface)
            
            # IPアドレス取得
            ip_addresses = []
            for addr in addrs:
                if addr.family.name in ['AF_INET', 'AF_INET6']:
                    ip_addresses.append({
                        'family': addr.family.name,
                        'address': addr.address
                    })
            
            if ip_addresses and if_stats:
                interfaces.append({
                    'name': interface,
                    'ip_addresses': ip_addresses,
                    'is_up': if_stats.isup,
                    'speed': if_stats.speed if if_stats.speed > 0 else None
                })
                
        return interfaces
        
    except Exception as e:
        print(f"Interface error: {e}")
        return []

def get_tailscale_status():
    """Tailscale状態確認"""
    try:
        # Tailscale IP取得
        result_ip = subprocess.run(['tailscale', 'ip', '-4'], 
                                 capture_output=True, text=True, timeout=5)
        
        # Tailscale状態取得
        result_status = subprocess.run(['tailscale', 'status'], 
                                     capture_output=True, text=True, timeout=5)
        
        if result_ip.returncode == 0 and result_status.returncode == 0:
            ip = result_ip.stdout.strip()
            return 'connected', ip
        else:
            return 'disconnected', None
            
    except Exception as e:
        print(f"Tailscale check error: {e}")
        return 'unknown', None

def update_network_data():
    """ネットワークデータ更新（バックグラウンド実行用）"""
    device_scan_counter = 0
    
    while True:
        try:
            print("Updating network data...")
            
            # 接続タイプ判定
            connection_type, interface = get_connection_type()
            network_data['connection_type'] = connection_type
            network_data['primary_interface'] = interface
            
            # Ping レイテンシ
            latency = ping_test()
            network_data['ping_latency'] = latency
            
            # ネットワークインターフェース
            interfaces = get_network_interfaces()
            network_data['network_interfaces'] = interfaces
            
            # Tailscale状態
            ts_status, ts_ip = get_tailscale_status()
            network_data['tailscale_status'] = ts_status
            network_data['tailscale_ip'] = ts_ip
            
            # 接続状態判定
            if latency is not None:
                network_data['connection_status'] = 'connected'
            else:
                network_data['connection_status'] = 'disconnected'
            
            # インターネット速度（時々測定）
            if int(time.time()) % 60 == 0:  # 1分に1回
                speed = internet_speed_test()
                network_data['internet_speed'] = speed
            
            # 接続機器スキャン（重い処理なので頻度を下げる）
            device_scan_counter += 1
            if device_scan_counter >= 6:  # 60秒に1回（10秒 x 6回）
                print("Scanning for connected devices...")
                devices = get_connected_devices()
                network_data['connected_devices'] = devices
                print(f"Found {len(devices)} connected devices")
                device_scan_counter = 0
            
            network_data['last_update'] = datetime.now().strftime('%H:%M:%S')
            print(f"Network data updated: {network_data['connection_status']}")
            
        except Exception as e:
            print(f"Network update error: {e}")
            network_data['connection_status'] = 'error'
        
        time.sleep(10)  # 10秒ごとに更新

@app.route('/')
def index():
    """メイン画面"""
    return render_template('network_monitor.html')

@app.route('/api/network-status')
def network_status():
    """ネットワーク状態API"""
    return jsonify(network_data)

@app.route('/api/ping-test')
def api_ping_test():
    """オンデマンドPingテスト"""
    host = request.args.get('host', '8.8.8.8')
    latency = ping_test(host)
    return jsonify({
        'host': host,
        'latency': latency,
        'status': 'success' if latency else 'failed',
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

@app.route('/api/speed-test')
def api_speed_test():
    """オンデマンド速度テスト"""
    speed = internet_speed_test()
    return jsonify({
        'speed_mbps': speed,
        'status': 'success' if speed else 'failed',
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

@app.route('/api/device-scan')
def api_device_scan():
    """オンデマンド機器スキャン"""
    devices = get_connected_devices()
    return jsonify({
        'devices': devices,
        'count': len(devices),
        'timestamp': datetime.now().strftime('%H:%M:%S'),
        'status': 'success' if devices else 'no_devices_found'
    })

# Google Drive関連ルート
@app.route('/gdrive')
def gdrive_dashboard():
    """Google Drive状態確認画面"""
    return render_template('gdrive_status.html')

@app.route('/api/gdrive-status')
def api_gdrive_status():
    """接続Google Drive状態API"""
    global gdrive_data
    
    if gdrive_manager:
        try:
            # 認証確認（まだ認証していない場合のみ）
            if not gdrive_manager._authenticated:
                print("Attempting Google Drive authentication...")
                auth_success = gdrive_manager.authenticate()
                if not auth_success:
                    gdrive_data.update({
                        'status': 'authentication_failed',
                        'message': '認証に失敗しました。credentials.jsonを確認してください。',
                        'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                    return jsonify(gdrive_data)
            
            # 接続状態確認
            status = gdrive_manager.check_connection()
            gdrive_data.update(status)
            
        except Exception as e:
            print(f"Google Drive API error: {e}")
            gdrive_data.update({
                'status': 'error',
                'message': f'エラー: {str(e)}',
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
    else:
        gdrive_data.update({
            'status': 'not_available',
            'message': 'Google Drive機能が無効です'
        })
    
    return jsonify(gdrive_data)

@app.route('/gdrive/test-upload')
def test_upload_page():
    """テスト送信画面"""
    return render_template('test_upload.html')

@app.route('/api/gdrive-test-upload', methods=['POST'])
def api_test_upload():
    """テストファイル送信API"""
    global gdrive_data
    
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        # リクエストデータ取得
        request_data = request.get_json() or {}
        data_type = request_data.get('data_type', 'test')
        
        # データ生成
        if data_type == 'network':
            data = DataSource.create_network_data(network_data)
        else:
            data = DataSource.create_test_data()
        
        filename = DataSource.get_filename(data_type)
        
        # Google Driveにアップロード
        result = gdrive_manager.upload_data(data, filename)
        
        # アップロード結果を保存
        if result['success']:
            gdrive_data['last_upload'] = {
                'filename': result['filename'],
                'upload_time': result['upload_time'],
                'data_type': data_type,
                'file_id': result.get('file_id'),
                'web_link': result.get('web_link')
            }
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'アップロードエラー: {str(e)}'
        }), 500

if __name__ == '__main__':
    # バックグラウンドでネットワーク監視開始
    network_thread = threading.Thread(target=update_network_data, daemon=True)
    network_thread.start()
    
    print("Starting Network Monitor App...")
    print("Access via: http://localhost:5000")
    print("Or via Tailscale: http://[tailscale-ip]:5000")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
