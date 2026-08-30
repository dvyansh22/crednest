import time
from transformers import pipeline

print("Downloading/loading distilbert pipeline...")
t0 = time.perf_counter()
classifier = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")
t_load = time.perf_counter() - t0
print(f"Model load time: {t_load:.2f}s")

sample_texts = [
    "I maintain strict financial discipline and never miss a payment.",
    "I sometimes panic and find cash flow unpredictable.",
    "I review my records weekly without fail."
]

print("Running inference latency test...")
latencies = []
for text in sample_texts:
    t1 = time.perf_counter()
    res = classifier(text)
    dt = time.perf_counter() - t1
    latencies.append(dt)
    print(f"Text: '{text}' -> {res} (took {dt*1000:.1f}ms)")

print(f"Average inference latency: {sum(latencies)/len(latencies)*1000:.1f}ms")
