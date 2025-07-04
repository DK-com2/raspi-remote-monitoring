# 動作確認とテスト例

## 基本動作確認

### Python環境テスト
```bash
# 仮想環境確認
echo $VIRTUAL_ENV
which python
python --version

# 基本ライブラリテスト
python -c "import flask; print(f'Flask: {flask.__version__}')"
python -c "import psutil; print(f'CPU: {psutil.cpu_percent()}%')"
python -c "import requests; print(f'Requests: {requests.__version__}')"
```

### ライブラリ一覧確認
```bash
# メインライブラリ確認
pip list | grep -E "(flask|psutil|requests|pandas)"

# 全ライブラリ数確認
pip list | wc -l
```

## システム情報取得テスト

### CPU・メモリ監視
```python
import psutil

# CPU使用率
print(f"CPU: {psutil.cpu_percent(interval=1)}%")

# メモリ使用率
memory = psutil.virtual_memory()
print(f"Memory: {memory.percent}% ({memory.used // 1024**2}MB / {memory.total // 1024**2}MB)")

# ディスク使用量
disk = psutil.disk_usage('/')
print(f"Disk: {disk.percent}% ({disk.free // 1024**3}GB free)")
```

### システム温度 (Raspberry Pi)
```python
import subprocess

try:
    result = subprocess.run(['vcgencmd', 'measure_temp'], 
                          capture_output=True, text=True)
    temp = result.stdout.strip().replace('temp=', '').replace("'C", '')
    print(f"Temperature: {temp}°C")
except:
    print("Temperature: Not available")
```

## ネットワークテスト

### 基本接続確認
```bash
# DNS解決テスト
nslookup google.com

# 外部サーバー疎通
ping -c 3 8.8.8.8

# Tailscale状態確認
tailscale status
tailscale ip -4
```

### Pythonでのネットワークテスト
```python
import requests
import subprocess

# HTTP通信テスト
try:
    response = requests.get('https://httpbin.org/ip', timeout=5)
    print(f"HTTP Test: {response.status_code}")
    print(f"External IP: {response.json()['origin']}")
except:
    print("HTTP Test: Failed")

# Ping テスト
try:
    result = subprocess.run(['ping', '-c', '3', '8.8.8.8'], 
                          capture_output=True, text=True, timeout=10)
    if result.returncode == 0:
        print("Ping Test: Success")
    else:
        print("Ping Test: Failed")
except:
    print("Ping Test: Error")
```

## Flask Webアプリテスト

### 最小構成のFlaskアプリ
```python
# test_flask.py
from flask import Flask
import psutil

app = Flask(__name__)

@app.route('/')
def index():
    cpu = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory().percent
    return f'''
    <h1>Monitoring Test</h1>
    <p>CPU: {cpu}%</p>
    <p>Memory: {memory}%</p>
    <p>Status: Running</p>
    '''

@app.route('/api/status')
def api_status():
    return {
        'cpu_percent': psutil.cpu_percent(interval=1),
        'memory_percent': psutil.virtual_memory().percent,
        'status': 'ok'
    }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

### Flaskアプリ実行テスト
```bash
# アプリ起動
python test_flask.py

# 別ターミナルで動作確認
curl http://localhost:8080
curl http://localhost:8080/api/status

# Tailscale経由確認 (スマホから)
# http://[TailscaleのIP]:8080
```

## トラブルシューティング用テスト

### 環境リセットテスト
```bash
# Python環境リセット
deactivate
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 動作確認
python -c "import flask, psutil; print('OK')"
```

### パフォーマンステスト
```python
import time
import psutil

print("Performance Test Start")
start_time = time.time()

# CPU負荷テスト
cpu_before = psutil.cpu_percent()
time.sleep(1)
cpu_after = psutil.cpu_percent()

# メモリ使用量
memory = psutil.virtual_memory()

# 結果表示
elapsed = time.time() - start_time
print(f"Test Duration: {elapsed:.2f}s")
print(f"CPU: {cpu_after}%")
print(f"Memory: {memory.percent}% ({memory.used // 1024**2}MB)")
print(f"Available Memory: {memory.available // 1024**2}MB")
```

### エラー時の診断情報
```bash
# システム情報
uname -a
cat /etc/os-release

# Python情報
python --version
pip --version
which python

# ディスク容量
df -h

# メモリ情報
free -h

# プロセス情報
ps aux | head -10
```

これらのテストを実行することで、環境が正しくセットアップされているか確認できます。
