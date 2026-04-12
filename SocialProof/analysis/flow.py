import graphviz
import os

# --- Configuration ---
output_filename = 'participant_journey'
output_format = 'png'
# --- End Configuration ---

def create_flowchart():
    """
    Creates and saves a flowchart of the participant journey.
    """
    
    # 1. Initialize the Graph
    dot = graphviz.Digraph(comment='Participant Journey Flowchart')
    dot.attr(rankdir='TB', fontsize='20', fontname='Inter')

    # 2. Define Styles
    node_style = {'shape': 'record', 'style': 'filled', 'fillcolor': '#e3f2fd', 'fontname': 'Inter'}
    edge_style = {'fontname': 'Inter'}
    loop_label_style = {'fontname': 'Inter', 'fontcolor': '#555555', 'fontsize': '10'}
    
    dot.attr('node', **node_style)
    dot.attr('edge', **edge_style)

    # 3. Define The Nodes (Phases)
    
    # Phase 1: Consent
    dot.node('consent',
             '{Consent (1 screen)}')

    # Phase 2: Instructions
    dot.node('instructions',
             '{Instructions (1 screen)}')

    # Phase 3: The Trial Loop (as a Subgraph to group them)
    with dot.subgraph(name='cluster_trial_loop') as c:
        c.attr(label='Trial Loop (Repeated 20 times)', style='dashed', fontname='Inter')
        
        # 3A. Stimulus Presentation
        c.node('stimulus',
               '{A. Stimulus Presentation|{LinkedIn post displayed with engagement metrics}}')
        
        # 3B. Response Page
        c.node('response',
               '{B. Response Page|{Question 1: "Who wrote this post?" → Select AI or Human (required)|Question 2: "How confident are you?" → Slider 0-100|Click "Next" to continue}}')
        
        # Edge inside the loop
        c.edge('stimulus', 'response')

    # Phase 4: Completion
    dot.node('completion',
             '{Completion (1 screen)|{Thank you message|Performance Summary|Download data option (CSV)}}')

    # 4. Define The Edges (Flow)
    
    # 1 -> 2
    dot.edge('consent', 'instructions')
    
    # 2 -> 3 (Start of loop)
    dot.edge('instructions', 'stimulus')

    # 3 -> 3 (The loop itself)
    # This edge goes from the end of the loop (response) back to the start (stimulus)
    # 'constraint=false' is a layout hint to prevent it from warping the main top-to-bottom flow
    dot.edge('response', 'stimulus', 
             label='  [Repeat 19 more times]', 
             style='dashed', 
             constraint='false', 
             **loop_label_style)

    # 3 -> 4 (Exiting the loop)
    dot.edge('response', 'completion', 
             label='[After 20th trial]  ', 
             **loop_label_style)

    # 5. Render and Save the File
    try:
        # cleanup=True will delete the temporary .dot source file, leaving only the .png
        dot.render(output_filename, format=output_format, cleanup=True) 
        print(f"\nFlowchart saved as '{output_filename}.{output_format}'")
        print(f"File is in your current directory: {os.getcwd()}")
    except graphviz.backend.execute.ExecutableNotFound:
        print("\n--- ERROR ---")
        print("Graphviz executable not found. This script requires the Graphviz system library.")
        print("On Pop!_OS/Ubuntu, you can install it with:")
        print("sudo apt-get install graphviz")
        print("\nYou also need the Python library:")
        print("pip install graphviz")
    except Exception as e:
        print(f"\nAn error occurred: {e}")

# --- Main execution ---
if __name__ == "__main__":
    create_flowchart()
