import hmac, base64, struct, hashlib, time, sys, json, subprocess

def get_totp_token(secret):
    secret = secret.replace(' ', '').upper()
    secret += '=' * (-len(secret) % 8)
    try:
        key = base64.b32decode(secret, True)
    except Exception:
        return "Invalid"
    msg = struct.pack(">Q", int(time.time() // 30))
    h = hmac.new(key, msg, hashlib.sha1).digest()
    o = h[19] & 15
    token = (struct.unpack(">I", h[o:o+4])[0] & 0x7fffffff) % 1000000
    return f"{token:06d}"

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
        
    action = sys.argv[1]
    
    if action == "get":
        accounts = json.loads(sys.argv[2])
        results = []
        for account in accounts:
            try:
                secret = subprocess.check_output(
                    ["secret-tool", "lookup", "noctalia-plugin", "authenticator", "account", account]
                ).decode('utf-8').strip()
                code = get_totp_token(secret) if secret else "No Secret"
            except Exception:
                code = "Error"
            results.append({
                "name": account,
                "code": code
            })
        print(json.dumps({
            "remaining": 30 - int(time.time() % 30),
            "codes": results
        }))
        
    elif action == "store":
        account = sys.argv[2]
        secret = sys.argv[3]
        subprocess.run(
            ["secret-tool", "store", "--label=OTP Authenticator", "noctalia-plugin", "authenticator", "account", account], 
            input=secret.encode('utf-8')
        )
        
    elif action == "delete":
        account = sys.argv[2]
        subprocess.run(["secret-tool", "clear", "noctalia-plugin", "authenticator", "account", account])
