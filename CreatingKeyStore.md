# 🔐 Secure Private Key Usage in Foundry via Encrypted Keystore

This guide shows how to **securely use your private key** in a Foundry project by encrypting it with a password-protected **keystore file** using `cast wallet import`.

## 🛠️ Step 1: Create an Encrypted Wallet

Run the following in your terminal:

    cast wallet import default --interactive

- ✅ You will be prompted to enter a **private key**
- ✅ Then you'll be prompted to set a **password**
- ✅ It will create an **encrypted keystore file** stored at:

    ~/.foundry/keystores/default

The keystore file is Geth-compatible and encrypted using:
- AES-128-CTR cipher
- Scrypt KDF (key derivation)

---

## 🔐 Example Keystore Format

    {
      "address": "0xYourAddress",
      "crypto": {
        "cipher": "aes-128-ctr",
        ...
      },
      "id": "uuid",
      "version": 3
    }

---

## ✅ Step 2: Use the Keystore in Forge Scripts

Deploy contracts securely using:

    forge script script/YourScript.s.sol \
      --rpc-url http://127.0.0.1:8545 \
      --broadcast \
      --wallet default

Foundry will:
- Detect the encrypted keystore in `~/.foundry/keystores/`
- Prompt you for the password
- Use it to sign and broadcast your transaction

---

## 🔒 Security Notes

| Practice                        | Recommendation             |
|----------------------------------|-----------------------------|
| Never commit `.foundry/keystores/` | ❌ Add to `.gitignore`     |
| Use strong, unique password     | ✅ Yes                      |
| Back up the keystore file       | ✅ Store securely           |
| Avoid hardcoding private keys   | ✅ Always use keystores     |

---

## 🔁 Optional: Use Named Wallets

Create multiple encrypted keystores:

    cast wallet import deployer --interactive
    cast wallet import backup --interactive

Use them by name:

    forge script ... --wallet deployer

---

## 🧪 Local Testing

Start Anvil:

    anvil

Deploy using your encrypted wallet:

    forge script script/DeployMinimalDex.s.sol \
      --wallet default \
      --broadcast \
      --rpc-url http://127.0.0.1:8545

You'll be securely prompted for your password.

---

## 📁 Summary

| Tool                 | Purpose                        |
|----------------------|--------------------------------|
| `cast wallet import` | Create encrypted keystore      |
| `forge script --wallet` | Use it securely in scripts  |
| Keystore Format      | AES-encrypted JSON (Geth-style)|

---

## 🧠 Pro Tip

To store keystores inside your project (instead of `~/.foundry`), you can:
- Add a `foundry.toml` and set a custom keystore path
- Or pass `--wallet-path <path>` in your `forge script` commands
