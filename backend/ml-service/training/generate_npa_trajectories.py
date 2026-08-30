import csv
import random
import numpy as np
from pathlib import Path

def generate_trajectories():
    out_dir = Path(__file__).resolve().parents[1] / "data" / "dataset"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "npa_trajectories.csv"

    samples = []
    
    # Generate 10000 samples
    num_samples_per_profile = 2000
    
    # Helper to add noise
    def add_noise(seq, noise_level=3):
        return [max(0, int(x + random.gauss(0, noise_level))) for x in seq]

    # 1. Stable Profile (Always low gaps -> default=0)
    for _ in range(num_samples_per_profile):
        sal = add_noise([random.randint(0, 10)] * 6, 2)
        gst = add_noise([random.randint(0, 5)] * 6, 1)
        samples.append(sal + gst + [0])
        
    # 2. Widening Degradation (Steadily worsening -> default=1)
    for _ in range(num_samples_per_profile):
        start_sal = random.randint(0, 15)
        end_sal = random.randint(45, 120)
        sal = add_noise(np.linspace(start_sal, end_sal, 6).tolist(), 5)
        
        start_gst = random.randint(0, 10)
        end_gst = random.randint(30, 90)
        gst = add_noise(np.linspace(start_gst, end_gst, 6).tolist(), 4)
        
        samples.append(sal + gst + [1])
        
    # 3. Recovered Spike (One bad month, then recovers -> default=0)
    for _ in range(num_samples_per_profile):
        sal = [random.randint(0, 10)] * 6
        gst = [random.randint(0, 5)] * 6
        spike_idx = random.randint(0, 4) # Spike must recover, so not the last month
        sal[spike_idx] = random.randint(45, 90)
        if random.random() > 0.5:
            gst[spike_idx] = random.randint(30, 60)
        samples.append(add_noise(sal, 2) + add_noise(gst, 2) + [0])
        
    # 4. Sudden Degradation (Stable, then crashes in last 1-2 months -> default=1)
    for _ in range(num_samples_per_profile):
        sal = [random.randint(0, 10)] * 6
        gst = [random.randint(0, 5)] * 6
        sal[4] = random.randint(30, 60)
        sal[5] = random.randint(60, 120)
        gst[4] = random.randint(15, 45)
        gst[5] = random.randint(45, 90)
        samples.append(add_noise(sal, 2) + add_noise(gst, 2) + [1])
        
    # 5. High but Constant / Borderline (30-45 day gaps constantly -> mix of 0 and 1)
    for _ in range(num_samples_per_profile):
        base_sal = random.randint(25, 45)
        base_gst = random.randint(15, 30)
        sal = add_noise([base_sal] * 6, 5)
        gst = add_noise([base_gst] * 6, 3)
        # Higher baseline means higher random risk of default
        default = 1 if random.random() > 0.6 else 0
        samples.append(sal + gst + [default])

    # Shuffle
    random.shuffle(samples)
    
    with open(out_path, "w", newline="") as f:
        writer = csv.writer(f)
        header = [f"salary_gap_m{i}" for i in range(1, 7)] + [f"gst_gap_m{i}" for i in range(1, 7)] + ["default_outcome"]
        writer.writerow(header)
        writer.writerows(samples)
        
    print(f"Generated {len(samples)} NPA trajectories at {out_path}")
    
    defaults = sum(s[-1] for s in samples)
    print(f"Defaults: {defaults} ({(defaults/len(samples))*100:.1f}%)")

if __name__ == "__main__":
    generate_trajectories()
