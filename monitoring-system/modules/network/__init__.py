"""
ネットワークモジュール
"""

from .monitor import NetworkMonitor
from .devices import DeviceDetector

class NetworkMonitor(NetworkMonitor):
    """デバイス検出機能を統合したネットワーク監視クラス"""
    
    def __init__(self):
        super().__init__()
        self.device_detector = DeviceDetector()
    
    def update_data(self):
        """ネットワークデータ更新（デバイス検出付き）"""
        data = super().update_data()
        
        # 定期的にデバイススキャン
        if not hasattr(self, '_device_scan_counter'):
            self._device_scan_counter = 0
        
        self._device_scan_counter += 1
        if self._device_scan_counter >= 6:  # 60秒に1回（10秒 x 6回）
            print("Scanning for connected devices...")
            devices = self.device_detector.scan_all_devices()
            self.data['connected_devices'] = devices
            print(f"Found {len(devices)} connected devices")
            self._device_scan_counter = 0
        
        return self.data

__all__ = ['NetworkMonitor', 'DeviceDetector']
