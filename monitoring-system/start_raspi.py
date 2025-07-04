#!/usr/bin/env python3
"""
Raspberry Pi用 アプリケーション起動スクリプト
環境検出と最適化された設定で起動
"""

import os
import sys
import platform
import subprocess
from pathlib import Path

def detect_environment():
    """環境検出"""
    system = platform.system()
    machine = platform.machine()
    
    # Raspberry Pi検出
    if machine.startswith('arm') and os.path.exists('/proc/device-tree/model'):
        try:
            with open('/proc/device-tree/model', 'r') as f:
                model = f.read().strip()
                if 'Raspberry Pi' in model:
                    return 'raspberry_pi', model
        except:
            pass
    
    return f"{system.lower()}_{machine.lower()}", f"{system} {machine}"

def setup_raspberry_pi():
    """Raspberry Pi特有の設定"""
    print("🍓 Raspberry Pi環境を検出しました")
    
    # GPUメモリ確認
    try:
        result = subprocess.run(['vcgencmd', 'get_mem', 'gpu'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print(f"📱 GPU メモリ: {result.stdout.strip()}")
    except:
        pass
    
    # カメラモジュール確認
    if os.path.exists('/dev/video0'):
        print("📷 カメラデバイス検出: /dev/video0")
    
    # I2C確認
    if os.path.exists('/dev/i2c-1'):
        print("🔌 I2C バス検出: /dev/i2c-1")
    
    return {
        'host': '0.0.0.0',
        'port': 5000,
        'debug': False,
        'update_interval': 10,  # ラズパイでは負荷軽減
        'device_scan_interval': 60  # デバイススキャン頻度を下げる
    }

def setup_development():
    """開発環境の設定"""
    print("🖥️ 開発環境を検出しました")
    
    return {
        'host': '0.0.0.0',
        'port': 5000,
        'debug': True,
        'update_interval': 5,   # 開発時は高頻度更新
        'device_scan_interval': 30
    }

def main():
    """メイン処理"""
    print("🚀 Raspberry Pi Monitor 起動システム")
    print("=" * 50)
    
    # 環境検出
    env_type, env_desc = detect_environment()
    print(f"🔍 検出環境: {env_desc}")
    
    # 設定選択
    if env_type.startswith('raspberry_pi'):
        config = setup_raspberry_pi()
        print("⚙️ Raspberry Pi最適化設定を適用")
    else:
        config = setup_development()
        print("⚙️ 開発環境設定を適用")
    
    # 環境変数設定
    os.environ['RASPI_HOST'] = config['host']
    os.environ['RASPI_PORT'] = str(config['port'])
    os.environ['RASPI_DEBUG'] = str(config['debug'])
    os.environ['RASPI_UPDATE_INTERVAL'] = str(config['update_interval'])
    os.environ['RASPI_DEVICE_SCAN_INTERVAL'] = str(config['device_scan_interval'])
    
    print(f"🌐 サーバー起動: http://{config['host']}:{config['port']}")
    print(f"🔧 デバッグモード: {config['debug']}")
    print("=" * 50)
    
    # アプリケーション起動
    try:
        from app import app
        app.run(
            host=config['host'],
            port=config['port'],
            debug=config['debug']
        )
    except ImportError:
        print("❌ app.py が見つかりません")
        print("📁 monitoring-system ディレクトリで実行してください")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 起動エラー: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
