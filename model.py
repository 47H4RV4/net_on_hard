import torch
from torchvision import datasets, transforms
import random

def float_to_q4_4_in_16bit(val):
    """Converts a float to a 16-bit binary string scaled to Q4.4."""
    # Scale by 2^4 = 16 for Q4.4 quantization
    scaled = int(round(val * 16))
    
    # Clip to 8-bit signed range (-128 to 127) for true Q4.4 magnitude
    scaled = max(-128, min(127, scaled))
    
    # Export as 16-bit binary string to keep the 16-bit data width
    return format(scaled & 0xFFFF, '016b')

# Load MNIST Test Dataset
dataset = datasets.MNIST(root='./data', train=False, download=True, 
                         transform=transforms.Compose([transforms.ToTensor()]))

# Select an image and flatten it
image_index = random.randint(0, 9999)
image, label = dataset[image_index]
pixels = image.view(-1).tolist()

# Save as 16-bit binary text for image_rom.v
output_filename = "C:\\Users\\mahar\\Forgery\\neuroFPGA\\self_coded\\net_on_hard\\mnist_sample.mif"
with open(output_filename, 'w') as f:
    for p in pixels:
        f.write(float_to_q4_4_in_16bit(p) + '\n')

print(f"Successfully exported Image Index {image_index} (Label: {label}) to {output_filename} as 16-bit Q4.4")