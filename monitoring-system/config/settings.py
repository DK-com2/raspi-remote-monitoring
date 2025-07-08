"""
設定管理モジュール
アプリケーション全体の設定を一元管理
"""

import os
import yaml
from typing import Dict, Any, Optional

class Settings:
    """設定管理クラス"""
    
    def __init__(self, config_path: Optional[str] = None):
        if config_path is None:
            # 現在のファイルから相対パスでconfig.yamlを探す
            current_dir = os.path.dirname(os.path.abspath(__file__))
            # config/ディレクトリから親ディレクトリのconfig.yamlを探す
            config_path = os.path.join(os.path.dirname(current_dir), 'config.yaml')
            
        self.config_path = config_path
        self._config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """設定ファイル読み込み"""
        if not self.config_path:
            print("設定ファイルパスが未指定 - デフォルト設定を使用")
            return self._get_default_config()
            
        try:
            if not os.path.exists(self.config_path):
                print(f"設定ファイルが見つかりません: {self.config_path}")
                print("デフォルト設定を使用します")
                return self._get_default_config()
                
            with open(self.config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f) or {}
                print(f"設定ファイル読み込み成功: {self.config_path}")
                print(f"読み込んだキー: {list(config.keys())}")
                return config
        except Exception as e:
            print(f"設定ファイル読み込みエラー: {e}")
            print("デフォルト設定を使用します")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """デフォルト設定"""
        return {
            'app': {
                'debug': True,
                'host': '0.0.0.0',
                'port': 5000
            },
            'network': {
                'update_interval': 10,
                'device_scan_interval': 60,
                'ping_host': '8.8.8.8',
                'ping_count': 3
            },
            'recording': {
                'default_duration': 10,
                'default_sample_rate': 44100,
                'default_channels': 2,
                'save_directory': '../data/recordings'
            },
            'gdrive': {
                'folder_name': 'raspi-monitoring',
                'credentials_file': '../data/credentials/credentials.json',
                'token_file': '../data/credentials/token.json',
                'auto_upload': False
            }
        }
    
    def get(self, key: str, default: Any = None) -> Any:
        """設定値取得（ドット記法対応）"""
        keys = key.split('.')
        value = self._config
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    
    def set(self, key: str, value: Any) -> None:
        """設定値設定（ドット記法対応）"""
        keys = key.split('.')
        config = self._config
        
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        
        config[keys[-1]] = value
    
    def save(self) -> bool:
        """設定ファイル保存"""
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                yaml.dump(self._config, f, default_flow_style=False, allow_unicode=True)
            return True
        except Exception as e:
            print(f"設定ファイル保存エラー: {e}")
            return False
    
    @property
    def app(self) -> Dict[str, Any]:
        """アプリケーション設定"""
        return self.get('app', {})
    
    @property
    def network(self) -> Dict[str, Any]:
        """ネットワーク設定"""
        return self.get('network', {})
    
    @property
    def recording(self) -> Dict[str, Any]:
        """録音設定"""
        return self.get('recording', {})
    
    @property
    def gdrive(self) -> Dict[str, Any]:
        """Google Drive設定"""
        return self.get('gdrive', {})

# グローバル設定インスタンス
settings = Settings()
