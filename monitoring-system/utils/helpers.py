"""
共通ユーティリティ
アプリケーション全体で使用される汎用機能
"""

import logging
import os
from datetime import datetime
from typing import Any, Dict, List, Optional

def setup_logging(log_level: str = 'INFO', log_file: Optional[str] = None) -> None:
    """ログ設定初期化"""
    level = getattr(logging, log_level.upper(), logging.INFO)
    
    # フォーマッター設定
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # ハンドラー設定
    handlers = [logging.StreamHandler()]
    
    if log_file:
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        handlers.append(logging.FileHandler(log_file))
    
    # ログ設定適用
    for handler in handlers:
        handler.setFormatter(formatter)
    
    logging.basicConfig(
        level=level,
        handlers=handlers,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

def safe_dict_get(data: Dict[str, Any], key: str, default: Any = None) -> Any:
    """安全な辞書値取得（ドット記法対応）"""
    try:
        keys = key.split('.')
        value = data
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    except Exception:
        return default

def format_file_size(bytes: int) -> str:
    """ファイルサイズを人間が読みやすい形式に変換"""
    if bytes == 0:
        return '0 B'
    
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes < 1024.0:
            return f"{bytes:.1f} {unit}"
        bytes /= 1024.0
    
    return f"{bytes:.1f} PB"

def validate_duration(duration: Any, min_val: int = 1, max_val: int = 3600) -> tuple[bool, int, str]:
    """録音時間のバリデーション"""
    try:
        duration = int(duration)
        
        if duration < min_val:
            return False, min_val, f'録音時間は{min_val}秒以上で指定してください'
        
        if duration > max_val:
            return False, max_val, f'録音時間は{max_val}秒以下で指定してください'
        
        return True, duration, ''
        
    except (ValueError, TypeError):
        return False, min_val, '録音時間は数値で指定してください'

def get_timestamp(format: str = '%Y-%m-%d %H:%M:%S') -> str:
    """現在時刻の文字列取得"""
    return datetime.now().strftime(format)

def ensure_directory(path: str) -> bool:
    """ディレクトリの存在確認・作成"""
    try:
        os.makedirs(path, exist_ok=True)
        return True
    except Exception as e:
        logging.error(f"Directory creation failed: {path}, error: {e}")
        return False

class ModuleStatus:
    """モジュール状態管理"""
    
    def __init__(self):
        self.modules = {}
    
    def register(self, name: str, instance: Any) -> None:
        """モジュール登録"""
        self.modules[name] = {
            'instance': instance,
            'status': 'initialized',
            'last_update': get_timestamp()
        }
    
    def update_status(self, name: str, status: str, message: str = '') -> None:
        """モジュール状態更新"""
        if name in self.modules:
            self.modules[name].update({
                'status': status,
                'message': message,
                'last_update': get_timestamp()
            })
    
    def get_status(self, name: Optional[str] = None) -> Dict[str, Any]:
        """モジュール状態取得"""
        if name:
            return self.modules.get(name, {})
        return {k: v for k, v in self.modules.items() if k != 'instance'}
    
    def is_healthy(self) -> bool:
        """全モジュールの健全性確認"""
        for module in self.modules.values():
            if module.get('status') == 'error':
                return False
        return True

# グローバル状態管理インスタンス
module_status = ModuleStatus()
