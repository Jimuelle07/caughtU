from functools import lru_cache

import cv2
from ultralytics import YOLO


@lru_cache(maxsize=1)
def _load_model(weights_path):
    return YOLO(weights_path)


def run_detection(video_path, weights_path, sample_fps=1.0):
    """Yields (frame_ts, label, bbox, confidence, crop_jpg_bytes) per detection."""
    model = _load_model(str(weights_path))
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise FileNotFoundError(f"cannot open video: {video_path}")

    try:
        video_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        stride = max(round(video_fps / sample_fps), 1)

        frame_idx = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break

            if frame_idx % stride == 0:
                frame_ts = frame_idx / video_fps
                for result in model.predict(frame, verbose=False):
                    for box in result.boxes:
                        x1, y1, x2, y2 = (int(v) for v in box.xyxy[0].tolist())
                        crop = frame[max(y1, 0):y2, max(x1, 0):x2]
                        if crop.size == 0:
                            continue
                        ok_enc, buf = cv2.imencode(".jpg", crop)
                        if not ok_enc:
                            continue
                        label = result.names[int(box.cls)]
                        yield frame_ts, label, (x1, y1, x2, y2), float(box.conf), buf.tobytes()

            frame_idx += 1
    finally:
        cap.release()
