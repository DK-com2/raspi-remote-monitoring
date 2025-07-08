"""
設定管理パッケージ
"""

from .settings import Settings

# グローバル設定インスタンス
settings = Settings()

__all__ = ['Settings', 'settings']
