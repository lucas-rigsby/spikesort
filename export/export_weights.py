"""
export_weights.py
─────────────────
Loads the trained PyTorch model, converts weights to Q8 fixed-point,
and writes them as Verilog-ready localparam declarations.

Run AFTER model/train_snn.py has completed successfully.
"""

import numpy as np
import torch
import json
import sys
import os

# Add model folder to path so we can import SpikeSorter
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from train_snn import SpikeSorter

# Q8 Conversion
def to_q8(tensor):
    """
    Convert float32 weights to signed 8-bit fixed point.
    Scale factor: 128 (i.e. 1.0 float → 128 integer)
    Clipped to [-128, 127] to fit int8 range.
    """
    scaled  = tensor.detach().numpy() * 128.0
    clipped = np.clip(np.round(scaled), -128, 127).astype(np.int8)
    return clipped

# Verilog localparam formatter
def format_verilog_weights(W_ih, W_ho):
    """
    Returns a string containing Verilog localparam declarations
    ready to paste into snn_core.v
    """
    lines = []
    lines.append("// ── Auto-generated Q8 weights from export/export_weights.py ──")
    lines.append("// W_IH: hidden layer  [4 neurons x 2 inputs]")
    lines.append("localparam signed [7:0] W_IH [0:3][0:1] = '{")
    for h in range(4):
        vals = ", ".join(f"{int(W_ih[h, c]):4d}" for c in range(2))
        comma = "," if h < 3 else ""
        lines.append(f"    '{{ {vals} }}{comma}   // H{h}")
    lines.append("};")
    lines.append("")
    lines.append("// W_HO: output layer  [3 neurons x 4 hidden]")
    lines.append("localparam signed [7:0] W_HO [0:2][0:3] = '{")
    for o in range(3):
        vals = ", ".join(f"{int(W_ho[o, h]):4d}" for h in range(4))
        comma = "," if o < 2 else ""
        lines.append(f"    '{{ {vals} }}{comma}   // O{o}")
    lines.append("};")
    return "\n".join(lines)

# Main
def export():
    print("Loading trained model...")
    model = SpikeSorter()
    model.load_state_dict(torch.load("model/spikesort_weights.pt"))
    model.eval()

    W_ih = to_q8(model.fc1.weight)   # shape (4, 2)
    W_ho = to_q8(model.fc2.weight)   # shape (3, 4)

    print(f"\nHidden layer weights W_IH (4x2):\n{W_ih}")
    print(f"\nOutput layer weights W_HO (3x4):\n{W_ho}")

    # Save as JSON
    weights_dict = {
        "W_ih": W_ih.tolist(),
        "W_ho": W_ho.tolist()
    }
    with open("export/weights_q8.json", "w") as f:
        json.dump(weights_dict, f, indent=2)
    print("\nSaved: export/weights_q8.json")

    # Save as Verilog localparam block
    verilog_str = format_verilog_weights(W_ih, W_ho)
    with open("export/weights_q8.vh", "w") as f:
        f.write(verilog_str + "\n")
    print("Saved: export/weights_q8.vh")

    # Print copy-paste block for snn_core.v
    print("\n" + "="*60)
    print("COPY THE BLOCK BELOW INTO rtl/snn_core.v")
    print("="*60)
    print(verilog_str)

if __name__ == "__main__":
    export()
