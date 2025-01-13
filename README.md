# macOS Dock App

This is a macOS-style dock implemented in Flutter. It supports smooth reordering via drag-and-drop, hover animations, tooltips, and now includes an enhanced "flight" animation for icons when dropped.

## Project Overview

This dock allows users to drag icons around to reorder them dynamically. If an icon is dropped outside the dock, it smoothly flies back to its original position. If it’s dropped onto the dock, it flies to the new slot with a neat animation. Hovering over icons triggers a subtle zoom effect and displays a tooltip.

### Key Features

- **Fully Animated Dock Items**  
  Icons have smooth animation when reordered, enlarging on hover, and a “flight” animation when released.
- **Drag-and-Drop with Reordering**  
  Icons can be dragged within the dock and automatically “push aside” other icons in real time.
- **Flight Animation**  
  If an icon is dropped outside the dock, it seamlessly flies back to its original spot. Dropping it onto the dock makes it fly to its new position.
- **Hover Effects & Tooltips**  
  Hovering over an icon shows a zoom effect and a tooltip with its label.

## How to Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/IgorKalinowskii/macos-dock-app.git
