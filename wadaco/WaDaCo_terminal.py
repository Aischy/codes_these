import csv
from datetime import datetime
import time
import os
import getpass
import EasyMCP2221
import sys

# --- Coefficients ---
line_frequency_m = 0.001
analog_input_m = 0.001
voltage_m = 0.1
current_m = 0.0001
active_power_m = 0.01
reactive_power_m = 0.01
apparent_power_m = 0.01

# --- Fonctions de conversion ---
def conversion_power_factor(raw_value):
    if raw_value & 0x8000:
        valeur_signee = raw_value - (1 << 16)
    else:
        valeur_signee = raw_value
    return valeur_signee / (2 ** 15)

def conversion_analog_brut_to_real(analog_input):
    v_dvdd = 3.3
    return analog_input * v_dvdd / 1023

def analog_to_temperature(voltage):
    millivolts = voltage * 1000
    return (millivolts - 500) / 10

# --- I2C ---
dev = EasyMCP2221.Device()
dev.I2C_speed(400_000)
I2C_ADDR = 0x74

def checksum(data):
    return sum(data) & 0xFF

def read_block(start_addr, length):
    frame = [0xA5, 0x08, 0x41, (start_addr >> 8) & 0xFF, start_addr & 0xFF, 0x4E, length]
    frame.append(checksum(frame))
    dev.I2C_write(I2C_ADDR, frame)
    time.sleep(0.001)
    response = dev.I2C_read(I2C_ADDR, 1 + 1 + length + 1)
    if response[0] != 0x06:
        raise RuntimeError("ACK manquant")
    return response[2:-1]

def parse_data(data1):
    def u16(offset): return int.from_bytes(data1[offset:offset+2], 'little')
    def s16(offset): return int.from_bytes(data1[offset:offset+2], 'little', signed=True)
    def u32(offset): return int.from_bytes(data1[offset:offset+4], 'little')

    system_status = int.from_bytes(data1[:2], 'little')
    sign_pa = 1 if (system_status & (1 << 4)) else -1
    sign_pr = 1 if (system_status & (1 << 5)) else -1

    return {
        "timestamp": datetime.now().isoformat(),
        "voltage_rms (V)":       u16(4) * voltage_m,
        "line_frequency (Hz)":   u16(6) * line_frequency_m,
        "analog_input (V)":      conversion_analog_brut_to_real(u16(8)),
        "temperature (°C)":      analog_to_temperature(conversion_analog_brut_to_real(u16(8))),
        "power_factor":          conversion_power_factor(s16(10)),
        "current_rms (A)":       u32(12) * current_m,
        "active_power (W)":      sign_pa * u32(16) * active_power_m,
        "reactive_power (vars)": sign_pr * u32(20) * reactive_power_m,
        "apparent_power (VA)":   u32(24) * apparent_power_m,
    }

# --- Capture ---
def run_capture(t_capture):
    filename = f"mcp_capture_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    with open(filename, 'w', newline='') as f:
        fieldnames = [
            "timestamp", "voltage_rms (V)", "line_frequency (Hz)", "analog_input (V)",
            "temperature (°C)", "power_factor", "current_rms (A)",
            "active_power (W)", "reactive_power (vars)", "apparent_power (VA)"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        t0 = time.time()
        print("Début de la capture. Ctrl+C pour arrêter.\n")
        header = f"{'Heure':<20} | {'P(W)':>8} | {'U(V)':>8} | {'I(A)':>8} | {'cos φ':>7} | {'Temp (°C)':>10}"
        print(header)
        print("-" * len(header))
        first_loop= True

        try:
            while time.time() - t0 < t_capture:
                data = read_block(0x0002, 28)
                row = parse_data(data)
                active_power = row["active_power (W)"]
                if not (-20 <= active_power <= 1000):
                    continue
                writer.writerow(row)

                line = f"{row['timestamp']:<20} | {active_power:8.2f} | {row['voltage_rms (V)']:8.1f} | {row['current_rms (A)']:8.3f} | {row['power_factor']:7.3f} | {row['temperature (°C)']:10.1f}"
                if first_loop:
                    first_loop = False
                else:
                    sys.stdout.write("\033[F")
                    #sys.stdout.write("\033[F")
                    
                    
                sys.stdout.write(line + "\n")
                sys.stdout.flush()

                time.sleep(0.05)
        except KeyboardInterrupt:
            print("\nCapture interrompue.")

    print(f"\nCapture terminée. Fichier: {filename}")
    return filename


# --- SSH Upload ---
def upload_to_ssh(local_path):
    print(local_path)
    remote_user = "ubuntu"
    password = "Maestr0!"
    remote_ip = "10.0.10.10"
    remote_path = "~/watt1/"
    print(f"Envoi du fichier via SCP...")
    os.system(f"sshpass -p '{password}' scp {local_path} {remote_user}@{remote_ip}:{remote_path}")


# --- Main ---
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <durée_en_secondes>")
        sys.exit(1)

    try:
        t_capture = int(sys.argv[1])
    except ValueError:
        print("Erreur : la durée doit être un entier.")
        sys.exit(1)

    filename = run_capture(t_capture)
    upload_to_ssh(filename)

