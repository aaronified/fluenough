"""Plain-numpy log-mel front end matching NeMo AudioToMelSpectrogramPreprocessor of the
AI4Bharat IndicConformer hybrid models (16 kHz, 25 ms hann, 10 ms hop, n_fft 512, 80 mels,
slaney mel, preemph 0.97, power 2, log(x + 2^-24), per-feature mean/std norm, no dither at eval)."""
import numpy as np

SR, N_FFT, WIN, HOP, N_MELS, PREEMPH = 16000, 512, 400, 160, 80, 0.97
LOG_GUARD = 2.0 ** -24

def _hz_to_mel(f):  # slaney
    f = np.asarray(f, dtype=np.float64)
    mel = f / (200.0 / 3)
    logstep = np.log(6.4) / 27.0
    return np.where(f >= 1000.0, 15.0 + np.log(np.maximum(f, 1e-9) / 1000.0) / logstep, mel)

def _mel_to_hz(m):
    m = np.asarray(m, dtype=np.float64)
    f = (200.0 / 3) * m
    logstep = np.log(6.4) / 27.0
    return np.where(m >= 15.0, 1000.0 * np.exp(logstep * (m - 15.0)), f)

def mel_filterbank(sr=SR, n_fft=N_FFT, n_mels=N_MELS, fmin=0.0, fmax=SR / 2):
    fftfreqs = np.linspace(0, sr / 2, 1 + n_fft // 2)
    mel_f = _mel_to_hz(np.linspace(_hz_to_mel(fmin), _hz_to_mel(fmax), n_mels + 2))
    fdiff = np.diff(mel_f)
    ramps = mel_f[:, None] - fftfreqs[None, :]
    lower = -ramps[:-2] / fdiff[:-1, None]
    upper = ramps[2:] / fdiff[1:, None]
    w = np.maximum(0, np.minimum(lower, upper))
    w *= (2.0 / (mel_f[2:n_mels + 2] - mel_f[:n_mels]))[:, None]  # slaney area norm
    return w.astype(np.float32)

_FB = mel_filterbank()
_WINDOW = np.zeros(N_FFT, dtype=np.float32)
_hw = np.hanning(WIN + 1)[:-1] if False else (0.5 - 0.5 * np.cos(2 * np.pi * np.arange(WIN) / (WIN - 1)))  # symmetric hann
_WINDOW[(N_FFT - WIN) // 2:(N_FFT - WIN) // 2 + WIN] = _hw

def log_mel(wav):
    """wav: float32 mono 16 kHz in [-1,1]. Returns (80, T) normalised features."""
    x = np.asarray(wav, dtype=np.float32)
    x = np.concatenate([x[:1], x[1:] - PREEMPH * x[:-1]])
    pad = N_FFT // 2
    xp = np.pad(x, (pad, pad), mode='reflect')
    n_frames = 1 + (len(xp) - N_FFT) // HOP
    idx = np.arange(N_FFT)[None, :] + HOP * np.arange(n_frames)[:, None]
    frames = xp[idx] * _WINDOW[None, :]
    spec = np.fft.rfft(frames, n=N_FFT, axis=1)
    power = (spec.real ** 2 + spec.imag ** 2).astype(np.float32).T  # (257, T)
    mel = _FB @ power
    feat = np.log(mel + LOG_GUARD)
    seq = len(x) // HOP + 1  # NeMo valid length (center=True)
    valid = feat[:, :seq]
    mean = valid.mean(axis=1, keepdims=True)
    std = valid.std(axis=1, ddof=1, keepdims=True) if seq > 1 else np.zeros_like(mean)
    return ((feat - mean) / (std + 1e-5)).astype(np.float32), seq
