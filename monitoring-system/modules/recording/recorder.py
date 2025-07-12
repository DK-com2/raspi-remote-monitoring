"""
録音機能モジュール
音声録音とファイル管理を担当
"""

import os
import subprocess
import threading
import time
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple

class AudioRecorder:
    """音声録音クラス"""
    
    def __init__(self, save_directory: str):
        self.save_directory = os.path.abspath(save_directory)
        self.data = {
            'is_recording': False,
            'start_time': None,
            'duration': 0,
            'filename': None,
            'filepath': None,
            'status': 'idle',
            'process': None,
            'selected_device': None,
            'last_recording': None,
            'elapsed_time': 0
        }
        
        # 録音ディレクトリ作成
        os.makedirs(self.save_directory, exist_ok=True)
        print(f"📁 録音保存ディレクトリ: {self.save_directory}")
    
    def get_audio_devices(self) -> List[Dict[str, Any]]:
        """利用可能な録音デバイスの一覧を取得"""
        try:
            devices = [{
                'id': 'default',
                'name': 'デフォルト録音デバイス',
                'type': 'ALSA',
                'description': 'システムのデフォルト設定'
            }]
            
            # ALSA録音デバイスの検出
            try:
                print("🔍 Detecting ALSA audio devices...")
                result = subprocess.run(['arecord', '-l'], capture_output=True, text=True, timeout=5)
                print(f"arecord -l result: {result.returncode}")
                
                if result.returncode == 0:
                    print(f"arecord output: {result.stdout}")
                    lines = result.stdout.split('\n')
                    for line in lines:
                        import re
                        # 日本語版と英語版の両方に対応
                        match = re.match(r'カード\s+(\d+):\s+([^\[]+)\s*\[([^\]]+)\].*デバイス\s+(\d+):\s*([^\[]+)\s*\[([^\]]+)\]', line)
                        if not match:
                            match = re.match(r'card\s+(\d+):\s+([^\[]+)\s*\[([^\]]+)\].*device\s+(\d+):\s*([^\[]+)\s*\[([^\]]+)\]', line, re.IGNORECASE)
                        
                        if match:
                            card_num, card_name, card_desc, device_num, device_name, device_desc = match.groups()
                            device_info = {
                                'id': f'hw:{card_num},{device_num}',
                                'name': f'{device_desc.strip()}',
                                'card': f'Card {card_num}',
                                'device': f'Device {device_num}',
                                'type': 'ALSA',
                                'description': f'{card_desc.strip()}'
                            }
                            devices.append(device_info)
                            print(f"Found device: {device_info}")
                else:
                    print(f"arecord error: {result.stderr}")
            except Exception as e:
                print(f"ALSA device detection error: {e}")
            
            print(f"🎤 Found {len(devices)} audio devices")
            return devices
            
        except Exception as e:
            print(f"Audio devices scan error: {e}")
            return []
    
    def start_recording(self, duration: int, device_id: str = 'default', 
                       sample_rate: int = 44100, channels: int = 2) -> Dict[str, Any]:
        """録音開始"""
        try:
            # 既に録音中の場合は停止
            if self.data['is_recording']:
                return {
                    'success': False,
                    'message': '既に録音中です'
                }
            
            # ファイル名生成
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f'recording_{timestamp}.wav'
            filepath = os.path.join(self.save_directory, filename)
            
            # 録音コマンド構築
            cmd = [
                'arecord',
                '-D', device_id,
                '-d', str(duration),
                '-r', str(sample_rate),
                '-c', str(channels),
                '-f', 'S16_LE',  # 16bit signed little endian
                '-t', 'wav',
                filepath
            ]
            
            print(f"Starting recording with command: {' '.join(cmd)}")
            
            # 録音プロセス開始
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # 録音状態更新
            self.data.update({
                'is_recording': True,
                'start_time': datetime.now(),
                'duration': duration,
                'filename': filename,
                'filepath': filepath,
                'status': 'recording',
                'process': process,
                'selected_device': device_id,
                'sample_rate': sample_rate,
                'channels': channels
            })
            
            return {
                'success': True,
                'message': f'{duration}秒間の録音を開始しました',
                'filename': filename,
                'duration': duration
            }
            
        except Exception as e:
            print(f"Recording start error: {e}")
            self.data['status'] = 'error'
            return {
                'success': False,
                'message': f'録音開始エラー: {str(e)}'
            }
    
    def stop_recording(self) -> Dict[str, Any]:
        """録音停止"""
        try:
            if self.data['is_recording'] and self.data['process']:
                # プロセス終了
                process = self.data['process']
                process.terminate()
                
                # プロセス終了待ち（最大5秒）
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                
                # 録音完了情報を保存
                end_time = datetime.now()
                actual_duration = (end_time - self.data['start_time']).total_seconds()
                
                # ファイルサイズ確認
                file_size = 0
                if os.path.exists(self.data['filepath']):
                    file_size = os.path.getsize(self.data['filepath'])
                
                self.data['last_recording'] = {
                    'filename': self.data['filename'],
                    'filepath': self.data['filepath'],
                    'start_time': self.data['start_time'].strftime('%Y-%m-%d %H:%M:%S'),
                    'end_time': end_time.strftime('%Y-%m-%d %H:%M:%S'),
                    'planned_duration': self.data['duration'],
                    'actual_duration': round(actual_duration, 2),
                    'file_size': file_size,
                    'device': self.data['selected_device'],
                    'sample_rate': self.data.get('sample_rate', 44100),
                    'channels': self.data.get('channels', 2)
                }
            
            # 録音状態リセット
            self.data.update({
                'is_recording': False,
                'start_time': None,
                'duration': 0,
                'filename': None,
                'filepath': None,
                'status': 'idle',
                'process': None
            })
            
            return {
                'success': True,
                'message': '録音を停止しました'
            }
            
        except Exception as e:
            print(f"Recording stop error: {e}")
            return {
                'success': False,
                'message': f'録音停止エラー: {str(e)}'
            }
    
    def get_status(self) -> Dict[str, Any]:
        """録音状態取得"""
        try:
            elapsed_time = 0
            remaining_time = 0
            
            if self.data['is_recording'] and self.data['start_time']:
                elapsed = (datetime.now() - self.data['start_time']).total_seconds()
                elapsed_time = round(elapsed, 1)
                remaining_time = max(0, self.data['duration'] - elapsed_time)
            
            status = self.data.copy()
            status.update({
                'elapsed_time': elapsed_time,
                'remaining_time': remaining_time,
                'timestamp': datetime.now().strftime('%H:%M:%S')
            })
            
            # プロセス情報は除外
            if 'process' in status:
                del status['process']
            
            return status
            
        except Exception as e:
            return {
                'error': str(e),
                'timestamp': datetime.now().strftime('%H:%M:%S')
            }
    
    def list_recordings(self) -> List[Dict[str, Any]]:
        """録音ファイル一覧取得"""
        try:
            if not os.path.exists(self.save_directory):
                return []
            
            files = []
            for filename in os.listdir(self.save_directory):
                if filename.endswith('.wav'):
                    filepath = os.path.join(self.save_directory, filename)
                    stat = os.stat(filepath)
                    files.append({
                        'filename': filename,
                        'size': stat.st_size,
                        'created': datetime.fromtimestamp(stat.st_ctime).strftime('%Y-%m-%d %H:%M:%S'),
                        'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                    })
            
            # 作成日時で降順ソート
            files.sort(key=lambda x: x['created'], reverse=True)
            return files
            
        except Exception as e:
            print(f"File list error: {e}")
            return []
    
    def get_file_path(self, filename: str) -> Optional[str]:
        """録音ファイルのパス取得"""
        filepath = os.path.join(self.save_directory, filename)
        if os.path.exists(filepath):
            return filepath
        return None
    
    def monitor_recording(self) -> None:
        """録音監視（バックグラウンド実行）"""
        while True:
            try:
                if self.data['is_recording'] and self.data['process']:
                    process = self.data['process']
                    
                    # プロセス状態確認
                    if process.poll() is not None:
                        # プロセスが終了している場合
                        print("Recording process finished")
                        self.stop_recording()
                    
                    # 録音時間更新
                    if self.data['start_time']:
                        elapsed = (datetime.now() - self.data['start_time']).total_seconds()
                        self.data['elapsed_time'] = round(elapsed, 1)
                
                time.sleep(1)
                
            except Exception as e:
                print(f"Recording monitor error: {e}")
                time.sleep(5)
