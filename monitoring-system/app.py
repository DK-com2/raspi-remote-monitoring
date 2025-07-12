#!/usr/bin/env python3
"""
Raspberry Pi 監視システム - モジュラー版
ネットワーク監視・録音・Google Drive連携機能をモジュール化
"""

from flask import Flask, render_template, jsonify, request, send_file
import threading
import time
import os
from datetime import datetime
from pathlib import Path

# 作業ディレクトリとパスの初期化
script_dir = Path(__file__).parent.absolute()
project_root = script_dir.parent  # raspi-remote-monitoring
data_dir = project_root / "data"

# 絶対パスでデータディレクトリを作成
os.makedirs(data_dir / "recordings", exist_ok=True)
os.makedirs(data_dir / "credentials", exist_ok=True)

print(f"📁 プロジェクトルート: {project_root}")
print(f"📁 データディレクトリ: {data_dir}")

# モジュールインポート
from config import settings
print(f"📝 設定情報: {settings._config.keys() if hasattr(settings, '_config') else '設定未読み込み'}")
print(f"🔍 ネットワーク設定: {settings.network}")

from modules.network import NetworkMonitor
from modules.recording import AudioRecorder
from modules.gdrive import GDriveManager, DataSource  # Google Drive連携機能

# Flaskアプリ初期化
app = Flask(__name__)

# モジュールインスタンス
network_monitor = NetworkMonitor()
audio_recorder = AudioRecorder(str(data_dir / "recordings"))

# Google Drive初期化（絶対パスで初期化）
try:
    # Google Drive用の設定を絶対パスで作成
    gdrive_config = {
        'gdrive': {
            'folder_name': 'raspi-monitoring',
            'credentials_file': str(data_dir / "credentials" / "credentials.json"),
            'token_file': str(data_dir / "credentials" / "token.json")
        }
    }
    
    # 一時的に設定ファイルを作成
    import tempfile
    import yaml
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump(gdrive_config, f)
        temp_config_path = f.name
    
    gdrive_manager = GDriveManager(temp_config_path)
    
    # 一時ファイルを削除
    os.unlink(temp_config_path)
    
    print("Google Drive manager initialized with absolute paths")
except Exception as e:
    print(f"Google Drive initialization failed: {e}")
    print("Google Drive機能を無効化します")
    gdrive_manager = None

# Google Drive用グローバル変数（互換性のため維持）
gdrive_data = {
    'connection_status': 'not_configured',
    'last_check': None,
    'user_email': None,
    'last_upload': None,
    'message': '未設定'
}

# ========================================
# メインページ
# ========================================

@app.route('/')
def index():
    """メインページ（モバイルダッシュボード）"""
    return render_template('mobile_dashboard.html')

@app.route('/dashboard')
def mobile_dashboard():
    """モバイルダッシュボード（メインと同じ）"""
    return render_template('mobile_dashboard.html')

@app.route('/network-monitor')
def network_monitor_legacy():
    """旧メインページ（互換性のため保持）"""
    return render_template('network_monitor.html')

@app.route('/tailscale')
def tailscale_page():
    """Tailscale管理ページ"""
    return render_template('tailscale_manage.html')

@app.route('/crontab')
def crontab_page():
    """Crontab管理ページ"""
    return render_template('crontab_manage.html')

@app.route('/devices')
def devices_page():
    """デバイス管理ページ"""
    return render_template('devices_manage.html')

@app.route('/network')
def network_page():
    """モバイル向けネットワーク詳細ページ"""
    return render_template('network_detail.html')

# ========================================
# ネットワーク監視API
# ========================================

@app.route('/api/network-status')
def network_status():
    """ネットワーク状態API"""
    return jsonify(network_monitor.get_data())

@app.route('/api/ping-test')
def api_ping_test():
    """オンデマンドPingテスト"""
    host = request.args.get('host', settings.network['ping_host'])
    latency = network_monitor.ping_test(host, settings.network['ping_count'])
    return jsonify({
        'host': host,
        'latency': latency,
        'status': 'success' if latency else 'failed',
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

@app.route('/api/speed-test')
def api_speed_test():
    """オンデマンド速度テスト"""
    speed = network_monitor.internet_speed_test()
    return jsonify({
        'speed_mbps': speed,
        'status': 'success' if speed else 'failed',
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

# 信号強度、DNS情報、デバイススキャンのAPIエンドポイントは削除
# シンプルなネットワークテストページではこれらの機能は不要

@app.route('/api/crontab-status')
def api_crontab_status():
    """クロンタブ状態確認API（改良版）"""
    try:
        import subprocess
        import os
        
        # デバッグ情報
        debug_info = {
            'user': os.getenv('USER', 'unknown'),
            'uid': os.getuid(),
            'crontab_path': None
        }
        
        # crontabコマンドの存在確認
        which_result = subprocess.run(['which', 'crontab'], capture_output=True, text=True, timeout=5)
        if which_result.returncode != 0:
            return jsonify({
                'status': 'error',
                'active_jobs': 0,
                'jobs': [],
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'crontabコマンドが見つかりません',
                'debug': debug_info
            })
        
        debug_info['crontab_path'] = which_result.stdout.strip()
        
        # crontab -l コマンドで現在のジョブ一覧を取得
        result = subprocess.run(['crontab', '-l'], capture_output=True, text=True, timeout=10)
        
        debug_info.update({
            'return_code': result.returncode,
            'stdout_length': len(result.stdout),
            'stderr': result.stderr.strip()
        })
        
        if result.returncode == 0:
            # 成功時の処理
            all_lines = result.stdout.split('\n')
            cron_lines = []
            invalid_lines = []
            
            for line in all_lines:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue  # 空行やコメントをスキップ
                
                # cron文法の簡易チェック（フィールド数確認）
                fields = line.split()
                if len(fields) >= 6:  # 最低6フィールド必要
                    cron_lines.append(line)
                else:
                    invalid_lines.append(line)
            
            active_jobs = len(cron_lines)
            message = f'{active_jobs}個のアクティブジョブ'
            
            if invalid_lines:
                message += f' (警告: {len(invalid_lines)}個の無効な行があります)'
            
            if active_jobs == 0 and not invalid_lines:
                message = 'アクティブなジョブなし'
            
            debug_info.update({
                'total_lines': len(all_lines),
                'valid_jobs': active_jobs,
                'invalid_lines': invalid_lines[:3] if invalid_lines else []
            })
            
            return jsonify({
                'status': 'active' if active_jobs > 0 else ('warning' if invalid_lines else 'inactive'),
                'active_jobs': active_jobs,
                'jobs': cron_lines[:5],  # 最初の5個のジョブを表示
                'invalid_jobs': invalid_lines[:3],  # 無効な行を最大3個表示
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': message,
                'debug': debug_info
            })
        else:
            # エラー時の詳細処理
            error_message = 'crontabコマンドの実行に失敗しました'
            
            # よくあるエラーパターンの判定
            stderr_lower = result.stderr.lower()
            if 'no crontab' in stderr_lower:
                error_message = 'このユーザーにはcrontabが設定されていません（正常状態）'
                status = 'inactive'
            elif 'permission denied' in stderr_lower:
                error_message = 'crontabへのアクセス権限がありません'
                status = 'permission_error'
            elif 'command not found' in stderr_lower:
                error_message = 'crontabコマンドがインストールされていません'
                status = 'not_installed'
            else:
                status = 'error'
            
            return jsonify({
                'status': status,
                'active_jobs': 0,
                'jobs': [],
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': error_message,
                'debug': debug_info
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'status': 'timeout',
            'active_jobs': 0,
            'jobs': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': 'crontabコマンドがタイムアウトしました'
        })
    except FileNotFoundError:
        return jsonify({
            'status': 'not_found',
            'active_jobs': 0,
            'jobs': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': 'crontabコマンドが見つかりません'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'active_jobs': 0,
            'jobs': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': f'エラー: {str(e)}'
        })

@app.route('/api/tailscale-status')
def api_tailscale_status():
    """Tailscale状態確認API"""
    try:
        import subprocess
        # tailscale status コマンドで状態確認
        result = subprocess.run(['tailscale', 'status'], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            status_lines = result.stdout.strip().split('\n')
            
            # 基本情報を解析
            connected = 'offline' not in result.stdout.lower()
            
            # IP アドレスを抽出
            tailscale_ip = None
            for line in status_lines:
                if 'self' in line.lower() or line.strip().startswith('100.'):
                    parts = line.split()
                    if len(parts) > 0:
                        tailscale_ip = parts[0]
                        break
            
            # 接続されたデバイス数を取得
            device_count = len([line for line in status_lines if line.strip() and not line.startswith('#')]) - 1
            
            return jsonify({
                'status': 'connected' if connected else 'disconnected',
                'ip_address': tailscale_ip,
                'device_count': max(0, device_count),
                'devices': status_lines[:10],  # 最初の10個のデバイス
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'Tailscale接続中' if connected else 'Tailscale切断中'
            })
        else:
            return jsonify({
                'status': 'error',
                'ip_address': None,
                'device_count': 0,
                'devices': [],
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'Tailscaleコマンドの実行に失敗しました（未インストールの可能性）'
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'status': 'timeout',
            'ip_address': None,
            'device_count': 0,
            'devices': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': 'Tailscaleコマンドがタイムアウトしました'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'ip_address': None,
            'device_count': 0,
            'devices': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': f'エラー: {str(e)}'
        })

@app.route('/api/tailscale-details')
def api_tailscale_details():
    """テイルスケール詳細情報API"""
    try:
        import subprocess
        
        # Tailscale状態取得
        status_result = subprocess.run(['tailscale', 'status'], capture_output=True, text=True, timeout=10)
        
        # ネットワークモニターから基本情報を取得
        network_data = network_monitor.get_data()
        
        tailscale_info = {
            'status': network_data.get('tailscale_status', 'unknown'),
            'ip': network_data.get('tailscale_ip', 'unknown'),
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'devices': [],
            'logs': [],
            'connection_quality': 'unknown'
        }
        
        if status_result.returncode == 0:
            status_lines = status_result.stdout.strip().split('\n')
            
            # デバイス一覧を解析
            devices = []
            for line in status_lines:
                if line.strip() and not line.startswith('#'):
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        # IPアドレスで始まる行をデバイスとして認識
                        if '.' in parts[0] or ':' in parts[0]:
                            devices.append({
                                'ip': parts[0],
                                'name': parts[1] if len(parts) > 1 else 'unknown',
                                'status': 'online' if len(parts) > 2 and 'online' in parts[2] else 'unknown'
                            })
            
            tailscale_info['devices'] = devices
            
            # 接続品質を判定
            if tailscale_info['status'] == 'connected':
                tailscale_info['connection_quality'] = 'good'
            elif tailscale_info['status'] == 'disconnected':
                tailscale_info['connection_quality'] = 'poor'
            
            # ログ情報を取得（簡易版）
            try:
                log_result = subprocess.run(['journalctl', '-u', 'tailscaled', '--no-pager', '-n', '10'], 
                                          capture_output=True, text=True, timeout=5)
                if log_result.returncode == 0:
                    log_lines = log_result.stdout.strip().split('\n')[-5:]  # 最後の5行
                    tailscale_info['logs'] = [line.strip() for line in log_lines if line.strip()]
            except:
                tailscale_info['logs'] = ['ログ情報を取得できません']
            
            tailscale_info['message'] = f'{len(devices)}個のデバイスが検出されました'
        else:
            tailscale_info['message'] = 'Tailscaleコマンドの実行に失敗しました'
            tailscale_info['status'] = 'error'
        
        return jsonify(tailscale_info)
        
    except subprocess.TimeoutExpired:
        return jsonify({
            'status': 'timeout',
            'ip': 'unknown',
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'devices': [],
            'logs': [],
            'connection_quality': 'poor',
            'message': 'Tailscaleコマンドがタイムアウトしました'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'ip': 'unknown',
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'devices': [],
            'logs': [],
            'connection_quality': 'poor',
            'message': f'エラー: {str(e)}'
        })

# ========================================
# 録音機能API
# ========================================

@app.route('/recording')
def recording_page():
    """録音機能画面"""
    return render_template('recording.html')

@app.route('/api/recording/devices')
def api_recording_devices():
    """利用可能な録音デバイス一覧"""
    devices = audio_recorder.get_audio_devices()
    return jsonify({
        'devices': devices,
        'count': len(devices),
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

@app.route('/api/recording/start', methods=['POST'])
def api_recording_start():
    """録音開始API"""
    try:
        data = request.get_json() or {}
        duration = int(data.get('duration', settings.recording['default_duration']))
        device_id = data.get('device_id', 'default')
        sample_rate = int(data.get('sample_rate', settings.recording['default_sample_rate']))
        channels = int(data.get('channels', settings.recording['default_channels']))
        
        if duration < 1 or duration > 3600:
            return jsonify({
                'success': False,
                'message': '録音時間は1秒から3600秒の間で指定してください'
            }), 400
        
        result = audio_recorder.start_recording(duration, device_id, sample_rate, channels)
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'録音開始エラー: {str(e)}'
        }), 500

@app.route('/api/recording/stop', methods=['POST'])
def api_recording_stop():
    """録音停止API"""
    try:
        result = audio_recorder.stop_recording()
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'録音停止エラー: {str(e)}'
        }), 500

@app.route('/api/recording/status')
def api_recording_status():
    """録音状態API"""
    return jsonify(audio_recorder.get_status())

@app.route('/api/recording/list')
def api_recording_list():
    """録音ファイル一覧"""
    try:
        files = audio_recorder.list_recordings()
        return jsonify({
            'files': files,
            'count': len(files),
            'timestamp': datetime.now().strftime('%H:%M:%S')
        })
        
    except Exception as e:
        return jsonify({
            'error': f'ファイル一覧取得エラー: {str(e)}'
        }), 500

@app.route('/api/recording/download/<filename>')
def api_recording_download(filename):
    """録音ファイルダウンロード"""
    try:
        filepath = audio_recorder.get_file_path(filename)
        
        if not filepath:
            return jsonify({
                'error': 'ファイルが見つかりません'
            }), 404
        
        return send_file(filepath, as_attachment=True)
        
    except Exception as e:
        return jsonify({
            'error': f'ダウンロードエラー: {str(e)}'
        }), 500

@app.route('/api/recording/upload-to-gdrive/<filename>', methods=['POST'])
def api_recording_upload_to_gdrive(filename):
    """録音ファイルをGoogle Driveにアップロード"""
    global gdrive_data
    
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        # ファイルパスを取得
        filepath = audio_recorder.get_file_path(filename)
        
        if not filepath:
            return jsonify({
                'success': False,
                'message': 'ファイルが見つかりません'
            }), 404
        
        # Google Driveにアップロード
        result = gdrive_manager.upload_file(filepath, filename)
        
        # アップロード結果を保存
        if result['success']:
            gdrive_data['last_upload'] = {
                'filename': result['filename'],
                'upload_time': result['upload_time'],
                'data_type': 'audio_recording',
                'file_id': result.get('file_id'),
                'web_link': result.get('web_link'),
                'file_size': result.get('file_size')
            }
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'アップロードエラー: {str(e)}'
        }), 500

@app.route('/api/gdrive-files')
def api_gdrive_files():
    """ファイル一覧API"""
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        limit = int(request.args.get('limit', 20))
        result = gdrive_manager.list_files(limit)
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'ファイル一覧取得エラー: {str(e)}'
        }), 500

@app.route('/api/gdrive-delete/<file_id>', methods=['DELETE'])
def api_gdrive_delete(file_id):
    """ファイル削除API"""
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        result = gdrive_manager.delete_file(file_id)
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'ファイル削除エラー: {str(e)}'
        }), 500

# ========================================
# Google Drive API（既存機能を維持）
# ========================================

@app.route('/gdrive')
def gdrive_dashboard():
    """Google Drive状態確認画面"""
    return render_template('gdrive_status.html')

@app.route('/api/gdrive-status')
def api_gdrive_status():
    """Google Drive状態API"""
    global gdrive_data
    
    if gdrive_manager:
        try:
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

# ========================================
# バックグラウンド処理
# ========================================

def network_monitor_loop():
    """ネットワーク監視ループ"""
    device_scan_counter = 0
    
    while True:
        try:
            # ネットワークデータ更新
            network_monitor.update_data()
            
            # デバイススキャン（頻度を下げる）
            device_scan_counter += 1
            if device_scan_counter >= (settings.network['device_scan_interval'] // settings.network['update_interval']):
                print("Scanning for connected devices...")
                # デバイス検出機能は将来実装
                device_scan_counter = 0
            
            time.sleep(settings.network['update_interval'])
            
        except Exception as e:
            print(f"Network monitor loop error: {e}")
            time.sleep(5)

def recording_monitor_loop():
    """録音監視ループ"""
    audio_recorder.monitor_recording()

# ========================================
# アプリケーション起動
# ========================================

if __name__ == '__main__':
    print("=" * 50)
    print("🚀 Raspberry Pi モニタリングシステム (モジュラー版)")
    print("=" * 50)
    
    # 設定情報表示
    print(f"📊 設定情報:")
    print(f"  - ネットワーク更新間隔: {settings.network['update_interval']}秒")
    print(f"  - 録音保存先: {audio_recorder.save_directory}")
    print(f"  - Google Drive: {'有効' if gdrive_manager else '無効'}")
    
    # データディレクトリは既に作成済み
    
    # バックグラウンド処理開始
    print("🔄 バックグラウンド処理を開始...")
    
    network_thread = threading.Thread(target=network_monitor_loop, daemon=True)
    network_thread.start()
    
    recording_thread = threading.Thread(target=recording_monitor_loop, daemon=True)
    recording_thread.start()
    
    # アクセス情報表示
    print("🌐 アクセス情報:")
    print(f"  - メインページ（ダッシュボード）: http://localhost:{settings.app['port']}/")
    print(f"  - ネットワークテスト: http://localhost:{settings.app['port']}/network")
    print(f"  - 録音機能: http://localhost:{settings.app['port']}/recording")
    if gdrive_manager:
        print(f"  - Google Drive: http://localhost:{settings.app['port']}/gdrive")
    print("📝 その他の管理ページ:")
    print(f"  - 詳細監視（レガシー）: http://localhost:{settings.app['port']}/network-monitor")
    print(f"  - Tailscale管理: http://localhost:{settings.app['port']}/tailscale")
    print(f"  - Crontab管理: http://localhost:{settings.app['port']}/crontab")
    print(f"  - デバイス管理: http://localhost:{settings.app['port']}/devices")
    print("=" * 50)
    
    # Flaskアプリ開始
    app.run(
        host=settings.app['host'],
        port=settings.app['port'],
        debug=settings.app['debug']
    )
