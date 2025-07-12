"""
ネットワーク監視モジュール（簡素化版・クロスプラットフォーム対応）
速度テストとPingテストのみに特化
"""

import subprocess
import re
import platform
import psutil
import requests
import time
from datetime import datetime
from typing import Dict, Optional

class NetworkMonitor:
    """ネットワーク監視クラス（簡素化版）"""
    
    def __init__(self):
        self.data = {
            'last_update': None,
            'ping_latency': None,
            'internet_speed': None,
            'connection_status': 'checking'
        }
        self.is_windows = platform.system().lower() == 'windows'
    
    def ping_test(self, host: str = '8.8.8.8', count: int = 3) -> Optional[float]:
        """Ping レイテンシテスト（クロスプラットフォーム対応）"""
        try:
            print(f"Ping test to {host} with {count} packets on {platform.system()}...")
            
            # プラットフォーム別のpingコマンド
            if self.is_windows:
                # Windows: ping -n count host
                cmd = ['ping', '-n', str(count), host]
            else:
                # Linux/Unix: ping -c count host
                cmd = ['ping', '-c', str(count), host]
            
            result = subprocess.run(
                cmd, 
                capture_output=True, text=True, timeout=15
            )
            
            if result.returncode == 0:
                # プラットフォーム別の出力解析
                latency = self._parse_ping_output(result.stdout)
                if latency:
                    print(f"Ping successful: {latency}ms")
                    return latency
                else:
                    print("Could not parse ping output")
                    print(f"Raw output: {result.stdout}")
            else:
                print(f"Ping failed with return code: {result.returncode}")
                print(f"Error output: {result.stderr}")
                print(f"Raw output: {result.stdout}")
            return None
            
        except subprocess.TimeoutExpired:
            print("Ping test timed out")
            return None
        except FileNotFoundError:
            print("Ping command not found")
            return None
        except Exception as e:
            print(f"Ping error: {e}")
            return None
    
    def _parse_ping_output(self, output: str) -> Optional[float]:
        """Pingコマンドの出力を解析してレイテンシを取得"""
        try:
            if self.is_windows:
                # Windows形式の解析
                # 例: "平均 = 23ms" または "Average = 23ms"
                patterns = [
                    r'平均\s*=\s*(\d+)ms',
                    r'Average\s*=\s*(\d+)ms',
                    r'時間\s*[<=]\s*(\d+)ms',
                    r'time\s*[<=]\s*(\d+)ms',
                    r'(\d+)ms'
                ]
                
                for pattern in patterns:
                    match = re.search(pattern, output, re.IGNORECASE)
                    if match:
                        return float(match.group(1))
                
                # 複数の時間値から平均を計算
                time_matches = re.findall(r'time\s*[<=]\s*(\d+)ms', output, re.IGNORECASE)
                if time_matches:
                    times = [float(t) for t in time_matches]
                    return sum(times) / len(times)
                    
            else:
                # Linux/Unix形式の解析
                # 例: "rtt min/avg/max/mdev = 1.234/5.678/9.012/1.234 ms"
                match = re.search(r'rtt min/avg/max/mdev = [\d.]+/([\d.]+)', output)
                if match:
                    return float(match.group(1))
            
            return None
            
        except Exception as e:
            print(f"Ping output parsing error: {e}")
            return None
    
    def internet_speed_test(self) -> Optional[float]:
        """簡易インターネット速度テスト"""
        try:
            print("Starting internet speed test...")
            # 小さなファイルをダウンロードして速度測定
            start_time = time.time()
            response = requests.get('http://httpbin.org/bytes/1048576', timeout=15)  # 1MB
            end_time = time.time()
            
            if response.status_code == 200:
                duration = end_time - start_time
                size_mb = len(response.content) / (1024 * 1024)
                speed_mbps = (size_mb * 8) / duration  # Mbps
                result = round(speed_mbps, 2)
                print(f"Speed test successful: {result} Mbps")
                return result
            else:
                print(f"Speed test failed with status: {response.status_code}")
                
        except requests.Timeout:
            print("Speed test timed out")
        except Exception as e:
            print(f"Speed test error: {e}")
            
        return None
    
    def test_connectivity(self) -> bool:
        """基本的な接続テスト"""
        try:
            # 簡単なHTTPリクエストで接続確認
            response = requests.get('http://www.google.com', timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def update_data(self) -> Dict[str, any]:
        """ネットワークデータ更新（基本情報のみ）"""
        try:
            print("Updating basic network data...")
            
            # Ping レイテンシ
            latency = self.ping_test()
            self.data['ping_latency'] = latency
            
            # 接続状態判定
            if latency is not None:
                self.data['connection_status'] = 'connected'
            else:
                # Pingが失敗した場合、基本的な接続テストを実行
                if self.test_connectivity():
                    self.data['connection_status'] = 'limited'  # 接続はあるがPingが失敗
                else:
                    self.data['connection_status'] = 'disconnected'
            
            # 最終更新時刻
            self.data['last_update'] = datetime.now().strftime('%H:%M:%S')
            print(f"Basic network data updated: {self.data['connection_status']}")
            
            return self.data
            
        except Exception as e:
            print(f"Network update error: {e}")
            self.data['connection_status'] = 'error'
            return self.data
    
    def get_data(self) -> Dict[str, any]:
        """現在のネットワークデータ取得"""
        return self.data.copy()
