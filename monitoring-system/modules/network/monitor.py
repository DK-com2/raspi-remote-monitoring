"""
ネットワーク監視モジュール
ネットワーク状態とデバイス検出を管理
"""

import subprocess
import re
import psutil
import requests
import time
import os
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple

class NetworkMonitor:
    """ネットワーク監視クラス"""
    
    def __init__(self):
        self.data = {
            'last_update': None,
            'ping_latency': None,
            'internet_speed': None,
            'connection_status': 'checking',
            'connection_type': 'unknown',
            'primary_interface': None,
            'network_interfaces': [],
            'tailscale_status': 'unknown',
            'tailscale_ip': None,
            'connected_devices': []
        }
    
    def get_connection_type(self) -> Tuple[str, Optional[str]]:
        """接続タイプの判定（WiFi/モバイル/有線）"""
        try:
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
    
    def ping_test(self, host: str = '8.8.8.8', count: int = 3) -> Optional[float]:
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
    
    def internet_speed_test(self) -> Optional[float]:
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
    
    def get_network_interfaces(self) -> List[Dict[str, Any]]:
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
    
    def get_tailscale_status(self) -> Tuple[str, Optional[str]]:
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
    
    def update_data(self) -> Dict[str, Any]:
        """ネットワークデータ更新"""
        try:
            print("Updating network data...")
            
            # 接続タイプ判定
            connection_type, interface = self.get_connection_type()
            self.data['connection_type'] = connection_type
            self.data['primary_interface'] = interface
            
            # Ping レイテンシ
            latency = self.ping_test()
            self.data['ping_latency'] = latency
            
            # ネットワークインターフェース
            interfaces = self.get_network_interfaces()
            self.data['network_interfaces'] = interfaces
            
            # Tailscale状態
            ts_status, ts_ip = self.get_tailscale_status()
            self.data['tailscale_status'] = ts_status
            self.data['tailscale_ip'] = ts_ip
            
            # 接続状態判定
            if latency is not None:
                self.data['connection_status'] = 'connected'
            else:
                self.data['connection_status'] = 'disconnected'
            
            # 最終更新時刻
            self.data['last_update'] = datetime.now().strftime('%H:%M:%S')
            print(f"Network data updated: {self.data['connection_status']}")
            
            return self.data
            
        except Exception as e:
            print(f"Network update error: {e}")
            self.data['connection_status'] = 'error'
            return self.data
    
    def get_signal_strength(self) -> Dict[str, Any]:
        """接続タイプ別信号強度取得"""
        connection_type, interface = self.get_connection_type()
        
        signal_data = {
            'connection_type': connection_type,
            'interface': interface,
            'signal_percent': 0,
            'signal_quality': 'unknown',
            'additional_info': {}
        }
        
        if connection_type == 'mobile':
            mobile_signal = self.get_mobile_signal_strength()
            if mobile_signal:
                signal_data.update(mobile_signal)
        elif connection_type == 'ethernet':
            ethernet_signal = self.get_ethernet_link_quality()
            if ethernet_signal:
                signal_data.update(ethernet_signal)
        
        return signal_data
    
    def get_mobile_signal_strength(self) -> Optional[Dict[str, Any]]:
        """モバイルネットワーク信号強度取得"""
        # Method 1: ModemManager
        mm_result = self.try_modem_manager_signal()
        if mm_result:
            return mm_result
        
        # Method 2: AT Commands  
        at_result = self.try_at_command_signal()
        if at_result:
            return at_result
        
        # Method 3: /sys filesystem
        sys_result = self.try_sys_mobile_signal()
        if sys_result:
            return sys_result
            
        return None
    
    def try_modem_manager_signal(self) -> Optional[Dict[str, Any]]:
        """モデムマネージャー経由で信号強度取得"""
        try:
            # mmcli -L でモデム一覧
            list_result = subprocess.run(['mmcli', '-L'], capture_output=True, text=True, timeout=10)
            if list_result.returncode != 0:
                return None
                
            # モデムIDを抽出
            modem_match = re.search(r'/org/freedesktop/ModemManager1/Modem/(\d+)', list_result.stdout)
            if not modem_match:
                return None
                
            modem_id = modem_match.group(1)
            
            # 信号強度取得
            signal_result = subprocess.run(
                ['mmcli', '-m', modem_id, '--signal-get'], 
                capture_output=True, text=True, timeout=10
            )
            
            if signal_result.returncode == 0:
                return self.parse_modem_manager_output(signal_result.stdout)
                
        except Exception as e:
            print(f"ModemManager signal error: {e}")
        
        return None
    
    def parse_modem_manager_output(self, output: str) -> Dict[str, Any]:
        """モデムマネージャー出力解析"""
        signal_data = {
            'signal_percent': 0,
            'signal_quality': 'poor',
            'additional_info': {}
        }
        
        # RSSI解析
        rssi_match = re.search(r'rssi:\s*([+-]?\d+\.?\d*)\s*dBm', output)
        if rssi_match:
            rssi = float(rssi_match.group(1))
            # RSSI → パーセント変換 (-50 〜 -120 dBm)
            signal_data['signal_percent'] = max(0, min(100, 100 + (rssi + 120) * 100 // 70))
            signal_data['additional_info']['rssi_dbm'] = rssi
            
            # 信号品質判定
            if rssi >= -70:
                signal_data['signal_quality'] = 'excellent'
            elif rssi >= -85:
                signal_data['signal_quality'] = 'good'
            elif rssi >= -100:
                signal_data['signal_quality'] = 'fair'
            else:
                signal_data['signal_quality'] = 'poor'
        
        # LTE固有指標
        rsrp_match = re.search(r'rsrp:\s*([+-]?\d+\.?\d*)\s*dBm', output)
        if rsrp_match:
            signal_data['additional_info']['rsrp_dbm'] = float(rsrp_match.group(1))
        
        rsrq_match = re.search(r'rsrq:\s*([+-]?\d+\.?\d*)\s*dB', output)
        if rsrq_match:
            signal_data['additional_info']['rsrq_db'] = float(rsrq_match.group(1))
        
        return signal_data
    
    def try_at_command_signal(self) -> Optional[Dict[str, Any]]:
        """エーティーコマンドで信号強度取得"""
        try:
            # USB モデムポートを探索
            for device in ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyUSB2', '/dev/ttyACM0']:
                if os.path.exists(device):
                    result = self.query_at_signal(device)
                    if result:
                        return result
            return None
            
        except Exception as e:
            print(f"AT command signal error: {e}")
            return None
    
    def query_at_signal(self, device: str) -> Optional[Dict[str, Any]]:
        """指定デバイスでAT+CSQ実行"""
        try:
            import serial
            with serial.Serial(device, 115200, timeout=3) as ser:
                ser.write(b'AT+CSQ\r\n')
                time.sleep(0.5)
                response = ser.read(100).decode('utf-8', errors='ignore')
                
                # +CSQ: 15,99 のような応答を解析
                match = re.search(r'\+CSQ:\s*(\d+),(\d+)', response)
                if match:
                    rssi_raw = int(match.group(1))
                    ber = int(match.group(2))
                    
                    # CSQ値をdBmに変換: CSQ = (dBm + 113) / 2
                    if 0 <= rssi_raw <= 31:
                        dbm = -113 + (rssi_raw * 2)
                        percentage = max(0, min(100, 100 + (dbm + 120) * 100 // 70))
                        
                        return {
                            'signal_percent': percentage,
                            'signal_quality': 'good' if percentage > 60 else 'fair' if percentage > 30 else 'poor',
                            'additional_info': {
                                'rssi_dbm': dbm,
                                'csq_value': rssi_raw,
                                'ber': ber
                            }
                        }
            return None
            
        except Exception as e:
            print(f"Serial AT command error: {e}")
            return None
    
    def try_sys_mobile_signal(self) -> Optional[Dict[str, Any]]:
        """/sys ファイルシステムでモバイル信号探索"""
        try:
            # USBモデムのネットワークインターフェースを探索
            for interface in ['wwan0', 'ppp0', 'usb0']:
                carrier_path = f'/sys/class/net/{interface}/carrier'
                operstate_path = f'/sys/class/net/{interface}/operstate'
                
                if os.path.exists(carrier_path) and os.path.exists(operstate_path):
                    with open(carrier_path, 'r') as f:
                        carrier = f.read().strip()
                    with open(operstate_path, 'r') as f:
                        operstate = f.read().strip()
                    
                    if carrier == '1' and operstate == 'up':
                        # 接続中の場合、基本的な情報を返す
                        return {
                            'signal_percent': 75,  # デフォルト値
                            'signal_quality': 'good',
                            'additional_info': {
                                'interface': interface,
                                'carrier': True,
                                'operstate': operstate
                            }
                        }
            
            return None
            
        except Exception as e:
            print(f"Sys mobile signal error: {e}")
            return None
    
    def get_ethernet_link_quality(self) -> Optional[Dict[str, Any]]:
        """有線ラン接続品質取得"""
        try:
            connection_type, interface = self.get_connection_type()
            if connection_type != 'ethernet' or not interface:
                return None
                
            # ethtool でリンク状態取得
            result = subprocess.run(['ethtool', interface], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                return self.parse_ethernet_quality(result.stdout, interface)
                
        except Exception as e:
            print(f"Ethernet quality error: {e}")
        
        return None
    
    def parse_ethernet_quality(self, output: str, interface: str) -> Dict[str, Any]:
        """ethtool出力解析"""
        signal_data = {
            'signal_percent': 0,
            'signal_quality': 'unknown',
            'additional_info': {'interface': interface}
        }
        
        # Link detected
        link_match = re.search(r'Link detected:\s*(yes|no)', output, re.IGNORECASE)
        if link_match:
            link_detected = link_match.group(1).lower() == 'yes'
            signal_data['signal_percent'] = 100 if link_detected else 0
            signal_data['signal_quality'] = 'excellent' if link_detected else 'no_link'
            signal_data['additional_info']['link_detected'] = link_detected
        
        # Speed
        speed_match = re.search(r'Speed:\s*(\d+)Mb/s', output)
        if speed_match:
            speed = int(speed_match.group(1))
            signal_data['additional_info']['speed_mbps'] = speed
            
            # 速度による品質判定補正
            if signal_data['additional_info'].get('link_detected', False):
                if speed >= 1000:
                    signal_data['signal_quality'] = 'excellent'
                elif speed >= 100:
                    signal_data['signal_quality'] = 'good'
                elif speed >= 10:
                    signal_data['signal_quality'] = 'fair'
                else:
                    signal_data['signal_quality'] = 'poor'
        
        # Duplex
        duplex_match = re.search(r'Duplex:\s*(Full|Half)', output, re.IGNORECASE)
        if duplex_match:
            signal_data['additional_info']['duplex'] = duplex_match.group(1)
        
        return signal_data
    
    def get_dns_server(self) -> Optional[str]:
        """/etc/resolv.confからDNSサーバーを取得"""
        try:
            with open('/etc/resolv.conf', 'r') as f:
                for line in f:
                    if line.strip().startswith('nameserver'):
                        parts = line.strip().split()
                        if len(parts) >= 2:
                            return parts[1]
            return None
        except Exception as e:
            print(f"DNS server detection error: {e}")
            return None
    
    def get_data(self) -> Dict[str, Any]:
        """現在のネットワークデータ取得"""
        return self.data.copy()
