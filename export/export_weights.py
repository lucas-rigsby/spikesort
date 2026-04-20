import numpy as np, torch, json, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from train_snn import SpikeSorter

def to_q8(tensor):
    scaled  = tensor.detach().numpy() * 128.0
    return np.clip(np.round(scaled), -128, 127).astype(np.int8)

def format_verilog_flat(W_ih, W_ho):
    """
    Generates individual localparam lines — Verilog-2001 compatible.
    No 2D array syntax. Each weight is a separate named parameter.
    Paste the printed block between the markers in snn_core.v.
    """
    lines = []
    lines.append("    // PASTE EXPORTED Q8 WEIGHTS HERE")
    lines.append("    // Hidden layer weights: WH_<neuron>_<input>")
    for h in range(W_ih.shape[0]):
        row = "    " + "  ".join(
            f'localparam signed [7:0] WH_{h}_{i} = {int(W_ih[h,i]):4d};'
            for i in range(W_ih.shape[1])
        )
        lines.append(row)
    lines.append("")
    lines.append("    // Output layer weights: WO_<neuron>_<hidden>")
    for o in range(W_ho.shape[0]):
        row = "    " + "  ".join(
            f'localparam signed [7:0] WO_{o}_{h} = {int(W_ho[o,h]):4d};'
            for h in range(W_ho.shape[1])
        )
        lines.append(row)
    lines.append("    //END WEIGHTS")
    return "\n".join(lines)

def export():
    print("Loading model...")
    model = SpikeSorter()
    model.load_state_dict(torch.load("model/spikesort_weights.pt", map_location="cpu"))
    model.eval()

    W_ih = to_q8(model.fc1.weight)
    W_ho = to_q8(model.fc2.weight)

    print(f"W_IH ({W_ih.shape[0]}x{W_ih.shape[1]}):\n{W_ih}")
    print(f"\nW_HO ({W_ho.shape[0]}x{W_ho.shape[1]}):\n{W_ho}")

    with open("export/weights_q8.json", "w") as f:
        json.dump({"W_ih": W_ih.tolist(), "W_ho": W_ho.tolist()}, f, indent=2)
    print("\nSaved: export/weights_q8.json")

    verilog_str = format_verilog_flat(W_ih, W_ho)
    with open("export/weights_q8.vh", "w") as f:
        f.write(verilog_str + "\n")
    print("Saved: export/weights_q8.vh")

    print("\n" + "="*70)
    print("PASTE THE BLOCK BELOW INTO snn_core.v (replace existing localparam lines)")
    print("="*70)
    print(verilog_str)

if __name__ == "__main__":
    export()
