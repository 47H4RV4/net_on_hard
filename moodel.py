import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import numpy as np

# 1. Hardware-Aware Architecture (784 -> 128 -> 32 -> 10)
class MNISTFixedPoint(nn.Module):
    def __init__(self):
        super(MNISTFixedPoint, self).__init__()
        self.fc1 = nn.Linear(784, 128)
        self.fc2 = nn.Linear(128, 32)
        self.fc3 = nn.Linear(32, 10)
        self.relu = nn.ReLU()

    def forward(self, x):
        x = x.view(-1, 784)
        x = self.relu(self.fc1(x))
        x = self.relu(self.fc2(x))
        x = self.fc3(x)
        return x

# 2. Conversion Logic: Float to Q4.4 Binary
# --- UPDATED CONVERSION LOGIC ---
# 2. Conversion Logic: Scale by 2^4 (Q4.4) but keep 16-bit width for Verilog
def float_to_q4_4_in_16bit_binary(tensor):
    # Move to CPU and convert to numpy
    numpy_data = tensor.cpu().detach().numpy()
    
    # Scaling factor for Q4.4 is 2^4 = 16
    scaled = (numpy_data * 16).astype(np.int32)
    
    # Clip to 8-bit range (-128 to 127) as Q4.4 is an 8-bit format
    # This ensures no single weight exceeds the intended Q4.4 magnitude
    clipped = np.clip(scaled, -128, 127)
    
    # Format as 16-bit binary strings to match your Verilog memory width
    binary_list = []
    for val in clipped.flatten():
        # Sign-extend to 16 bits for the MIF file
        bin_str = format(val & 0xFFFF, '016b')
        binary_list.append(bin_str)
    return binary_list

# 3. MIF File Writer
def save_as_mif(data_list, filename):
    with open(filename, 'w') as f:
        for line in data_list:
            f.write(line + '\n')
    print(f"Saved: {filename}")

# ... (Architecture remains the same) ...

# --- TRAINING WITH Q4.4 CONSTRAINTS ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = MNISTFixedPoint().to(device)
optimizer = optim.Adam(model.parameters(), lr=0.001)
criterion = nn.CrossEntropyLoss()

# Load MNIST
train_loader = torch.utils.data.DataLoader(
    datasets.MNIST('./data', train=True, download=True,
                   transform=transforms.Compose([transforms.ToTensor()])),
    batch_size=64, shuffle=True)

print("Starting Training with Q4.4 Constraints...")
model.train()
for epoch in range(1, 4): # 3 epochs for better stability
    for batch_idx, (data, target) in enumerate(train_loader):
        data, target = data.to(device), target.to(device)
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()

        # --- THE TACKLE: Prevent Hardware Saturation ---
        # We clamp weights to the Q4.4 range (-8.0 to 7.93).
        # However, to prevent the 784-input sum from saturating your 
        # hardware's 16-bit extraction point, we use a tighter clamp.
        with torch.no_grad():
            for param in model.parameters():
                param.clamp_(-1.0, 1.0) # Prevents L1 sums from exploding

    print(f"Epoch {epoch} Complete.")

# --- LAYER-WISE EXPORT ---
print("\nExporting Q4.4 weights in 16-bit MIF format...")
layers = [(model.fc1, "layer_1"), (model.fc2, "layer_2"), (model.fc3, "layer_3")]

for layer_obj, name in layers:
    # Use the new Q4.4 scaling function
    w_bin = float_to_q4_4_in_16bit_binary(layer_obj.weight)
    save_as_mif(w_bin, f"{name}_weights.mif")
    
    b_bin = float_to_q4_4_in_16bit_binary(layer_obj.bias)
    save_as_mif(b_bin, f"{name}_biases.mif")