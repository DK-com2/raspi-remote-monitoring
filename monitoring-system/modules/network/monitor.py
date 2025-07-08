"""
ネットワーク監視モジュール
ネットワーク状態とデバイス検出を管理
"""

import subprocess
import re
import psutil
import requests
import time
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
    
    def get_data(self) -> Dict[str, Any]:
        """現在のネットワークデータ取得"""
        return self.data.copy()
