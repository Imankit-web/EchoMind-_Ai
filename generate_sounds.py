import wave
import math
import struct
import os

def generate_tone(filename, duration_ms, frequency, fade_out_ms=10, wave_type='sine'):
    # Ensure directory exists
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    sample_rate = 44100
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    fade_out_samples = int(sample_rate * (fade_out_ms / 1000.0))
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            # Base waveform
            t = float(i) / sample_rate
            if wave_type == 'sine':
                value = math.sin(2.0 * math.pi * frequency * t)
            elif wave_type == 'square':
                value = 1.0 if math.sin(2.0 * math.pi * frequency * t) > 0 else -1.0
            
            # Envelope (fade out)
            envelope = 1.0
            if num_samples - i < fade_out_samples:
                envelope = (num_samples - i) / fade_out_samples
            
            # Dampen amplitude to be "soft" and professional
            amplitude = 8000 * envelope
            
            # Pack as 16-bit PCM
            data = struct.pack('<h', int(value * amplitude))
            wav_file.writeframesraw(data)

# 1. Soft click (blink) - Very short, high pitch pop
generate_tone('assets/sounds/blink_click.wav', duration_ms=15, frequency=1200, fade_out_ms=10, wave_type='sine')

# 2. Light tap (option) - Slightly longer, woody/mid pitch pop
generate_tone('assets/sounds/option_tap.wav', duration_ms=25, frequency=800, fade_out_ms=20, wave_type='sine')

# 3. Soft tone (speaking) - Smooth musical tone (e.g., A4 440Hz), short
generate_tone('assets/sounds/speak_tone.wav', duration_ms=150, frequency=440, fade_out_ms=60, wave_type='sine')

print("Custom UI sounds generated successfully in assets/sounds/")
