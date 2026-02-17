#!/usr/bin/env python3
"""
dwarven_stronghold_gen.py - OBJ mesh generator for dwarven stronghold assets

Generates 60+ low-poly OBJ meshes in PS1 aesthetic for the Kazan-Dun modular room system.
Meshes are organized into themed categories:
  - residential: beds, hearths, barrels, tables, benches
  - market: stalls, crates, sacks, signs, carts
  - forge: anvils, furnaces, bellows, tool racks
  - bridge: sections, pillars, guard posts, dwarf statues
  - vault: vault doors, treasure piles, chests, rune wards

Usage:
  python dwarven_stronghold_gen.py --zone all --output ./assets/meshes/dwarven/
  python dwarven_stronghold_gen.py --zone forge --output ./assets/meshes/dwarven/
  python dwarven_stronghold_gen.py --list
"""

import argparse
import os
import math
from typing import List, Tuple, Dict, Any


class OBJWriter:
    """Writes OBJ file format with vertices, normals, and faces."""

    def __init__(self, name: str):
        self.name = name
        self.vertices: List[Tuple[float, float, float]] = []
        self.normals: List[Tuple[float, float, float]] = []
        self.faces: List[List[Tuple[int, int]]] = []  # List of (vertex_idx, normal_idx) tuples
        self.vertex_offset = 0
        self.normal_offset = 0

    def add_vertex(self, x: float, y: float, z: float) -> int:
        """Add a vertex and return its 1-based index."""
        self.vertices.append((x, y, z))
        return len(self.vertices)

    def add_normal(self, x: float, y: float, z: float) -> int:
        """Add a normal and return its 1-based index."""
        length = math.sqrt(x*x + y*y + z*z)
        if length > 0:
            x, y, z = x/length, y/length, z/length
        self.normals.append((x, y, z))
        return len(self.normals)

    def add_face(self, vertex_indices: List[int], normal_idx: int):
        """Add a face with vertex indices (1-based) sharing a normal."""
        self.faces.append([(v, normal_idx) for v in vertex_indices])

    def add_box(self, cx: float, cy: float, cz: float,
                sx: float, sy: float, sz: float) -> None:
        """Add a box centered at (cx, cy, cz) with size (sx, sy, sz)."""
        hx, hy, hz = sx/2, sy/2, sz/2

        # 8 vertices of the box
        v = [
            self.add_vertex(cx - hx, cy - hy, cz - hz),  # 0: left-bottom-back
            self.add_vertex(cx + hx, cy - hy, cz - hz),  # 1: right-bottom-back
            self.add_vertex(cx + hx, cy + hy, cz - hz),  # 2: right-top-back
            self.add_vertex(cx - hx, cy + hy, cz - hz),  # 3: left-top-back
            self.add_vertex(cx - hx, cy - hy, cz + hz),  # 4: left-bottom-front
            self.add_vertex(cx + hx, cy - hy, cz + hz),  # 5: right-bottom-front
            self.add_vertex(cx + hx, cy + hy, cz + hz),  # 6: right-top-front
            self.add_vertex(cx - hx, cy + hy, cz + hz),  # 7: left-top-front
        ]

        # 6 normals for each face
        n_front = self.add_normal(0, 0, 1)
        n_back = self.add_normal(0, 0, -1)
        n_right = self.add_normal(1, 0, 0)
        n_left = self.add_normal(-1, 0, 0)
        n_top = self.add_normal(0, 1, 0)
        n_bottom = self.add_normal(0, -1, 0)

        # 6 faces (quads, CCW winding)
        self.add_face([v[4], v[5], v[6], v[7]], n_front)   # Front
        self.add_face([v[1], v[0], v[3], v[2]], n_back)    # Back
        self.add_face([v[5], v[1], v[2], v[6]], n_right)   # Right
        self.add_face([v[0], v[4], v[7], v[3]], n_left)    # Left
        self.add_face([v[7], v[6], v[2], v[3]], n_top)     # Top
        self.add_face([v[0], v[1], v[5], v[4]], n_bottom)  # Bottom

    def add_cylinder(self, cx: float, cy: float, cz: float,
                     radius: float, height: float, sides: int = 8) -> None:
        """Add a low-poly cylinder (for barrels, pillars, etc.)."""
        hy = height / 2

        # Bottom and top center vertices
        bottom_center = self.add_vertex(cx, cy - hy, cz)
        top_center = self.add_vertex(cx, cy + hy, cz)

        # Bottom and top ring vertices
        bottom_ring = []
        top_ring = []
        for i in range(sides):
            angle = 2 * math.pi * i / sides
            x = cx + radius * math.cos(angle)
            z = cz + radius * math.sin(angle)
            bottom_ring.append(self.add_vertex(x, cy - hy, z))
            top_ring.append(self.add_vertex(x, cy + hy, z))

        # Normals
        n_bottom = self.add_normal(0, -1, 0)
        n_top = self.add_normal(0, 1, 0)

        # Bottom cap (fan from center)
        for i in range(sides):
            next_i = (i + 1) % sides
            self.add_face([bottom_center, bottom_ring[next_i], bottom_ring[i]], n_bottom)

        # Top cap (fan from center)
        for i in range(sides):
            next_i = (i + 1) % sides
            self.add_face([top_center, top_ring[i], top_ring[next_i]], n_top)

        # Side faces
        for i in range(sides):
            next_i = (i + 1) % sides
            angle = 2 * math.pi * (i + 0.5) / sides
            n_side = self.add_normal(math.cos(angle), 0, math.sin(angle))
            self.add_face([bottom_ring[i], bottom_ring[next_i],
                          top_ring[next_i], top_ring[i]], n_side)

    def add_wedge(self, cx: float, cy: float, cz: float,
                  sx: float, sy: float, sz: float,
                  direction: str = "x+") -> None:
        """Add a triangular prism (wedge) for roofs, ramps, etc."""
        hx, hy, hz = sx/2, sy/2, sz/2

        if direction == "x+":
            # Peak along +X edge
            v = [
                self.add_vertex(cx - hx, cy - hy, cz - hz),  # 0
                self.add_vertex(cx + hx, cy - hy, cz - hz),  # 1
                self.add_vertex(cx + hx, cy + hy, cz),       # 2 (peak)
                self.add_vertex(cx - hx, cy + hy, cz),       # 3 (peak)
                self.add_vertex(cx - hx, cy - hy, cz + hz),  # 4
                self.add_vertex(cx + hx, cy - hy, cz + hz),  # 5
            ]
            n_back = self.add_normal(0, hz, -sy)
            n_front = self.add_normal(0, hz, sy)
            n_bottom = self.add_normal(0, -1, 0)
            n_left = self.add_normal(-1, 0, 0)
            n_right = self.add_normal(1, 0, 0)

            self.add_face([v[0], v[1], v[2], v[3]], n_back)
            self.add_face([v[5], v[4], v[3], v[2]], n_front)
            self.add_face([v[0], v[4], v[5], v[1]], n_bottom)
            self.add_face([v[0], v[3], v[4]], n_left)
            self.add_face([v[1], v[5], v[2]], n_right)
        else:
            # Peak along +Z edge (default for most roofs)
            v = [
                self.add_vertex(cx - hx, cy - hy, cz - hz),  # 0: left-bottom-back
                self.add_vertex(cx + hx, cy - hy, cz - hz),  # 1: right-bottom-back
                self.add_vertex(cx + hx, cy - hy, cz + hz),  # 2: right-bottom-front
                self.add_vertex(cx - hx, cy - hy, cz + hz),  # 3: left-bottom-front
                self.add_vertex(cx, cy + hy, cz - hz),       # 4: top-back (peak)
                self.add_vertex(cx, cy + hy, cz + hz),       # 5: top-front (peak)
            ]
            n_bottom = self.add_normal(0, -1, 0)
            n_left = self.add_normal(-hx, hy, 0)
            n_right = self.add_normal(hx, hy, 0)
            n_back = self.add_normal(0, 0, -1)
            n_front = self.add_normal(0, 0, 1)

            self.add_face([v[0], v[1], v[2], v[3]], n_bottom)
            self.add_face([v[0], v[3], v[5], v[4]], n_left)
            self.add_face([v[1], v[4], v[5], v[2]], n_right)
            self.add_face([v[0], v[4], v[1]], n_back)
            self.add_face([v[3], v[2], v[5]], n_front)

    def add_pyramid(self, cx: float, cy: float, cz: float,
                    base_size: float, height: float, sides: int = 4) -> None:
        """Add a pyramid shape for decorative elements."""
        hy = height / 2
        hr = base_size / 2

        apex = self.add_vertex(cx, cy + hy, cz)
        base_verts = []

        for i in range(sides):
            angle = 2 * math.pi * i / sides + math.pi / 4  # Rotated 45 degrees for square base
            x = cx + hr * math.cos(angle)
            z = cz + hr * math.sin(angle)
            base_verts.append(self.add_vertex(x, cy - hy, z))

        # Bottom face
        n_bottom = self.add_normal(0, -1, 0)
        if sides == 4:
            self.add_face([base_verts[0], base_verts[1], base_verts[2], base_verts[3]], n_bottom)
        else:
            # Fan triangulation for non-quad bases
            center = self.add_vertex(cx, cy - hy, cz)
            for i in range(sides):
                next_i = (i + 1) % sides
                self.add_face([center, base_verts[next_i], base_verts[i]], n_bottom)

        # Side faces
        for i in range(sides):
            next_i = (i + 1) % sides
            angle = 2 * math.pi * (i + 0.5) / sides + math.pi / 4
            n_side = self.add_normal(math.cos(angle), 0.5, math.sin(angle))
            self.add_face([base_verts[i], base_verts[next_i], apex], n_side)

    def write(self, filepath: str) -> None:
        """Write the OBJ file to disk."""
        os.makedirs(os.path.dirname(filepath), exist_ok=True)

        with open(filepath, 'w') as f:
            f.write(f"# Dwarven Stronghold Asset: {self.name}\n")
            f.write(f"# Generated by dwarven_stronghold_gen.py\n")
            f.write(f"# Vertices: {len(self.vertices)}, Faces: {len(self.faces)}\n\n")

            f.write(f"o {self.name}\n\n")

            # Write vertices
            for v in self.vertices:
                f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
            f.write("\n")

            # Write normals
            for n in self.normals:
                f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")
            f.write("\n")

            # Write faces
            for face in self.faces:
                face_str = " ".join([f"{v}//{n}" for v, n in face])
                f.write(f"f {face_str}\n")


# =============================================================================
# MESH GENERATORS BY ZONE
# =============================================================================

def generate_residential_meshes(output_dir: str) -> List[str]:
    """Generate meshes for residential zone: beds, hearths, barrels, tables, benches."""
    generated = []
    zone_dir = os.path.join(output_dir, "residential")

    # --- BEDS ---

    # Single bed (simple frame + mattress)
    obj = OBJWriter("bed_single")
    obj.add_box(0, 0.15, 0, 1.0, 0.3, 2.0)  # Frame
    obj.add_box(0, 0.35, 0, 0.9, 0.1, 1.9)  # Mattress
    obj.add_box(0, 0.5, -0.85, 0.9, 0.3, 0.1)  # Headboard
    obj.write(os.path.join(zone_dir, "bed_single.obj"))
    generated.append("residential/bed_single.obj")

    # Double bed
    obj = OBJWriter("bed_double")
    obj.add_box(0, 0.15, 0, 1.5, 0.3, 2.2)
    obj.add_box(0, 0.35, 0, 1.4, 0.12, 2.1)
    obj.add_box(0, 0.55, -1.0, 1.4, 0.4, 0.12)
    obj.add_box(-0.65, 0.15, -0.95, 0.1, 0.5, 0.1)  # Bedpost left
    obj.add_box(0.65, 0.15, -0.95, 0.1, 0.5, 0.1)   # Bedpost right
    obj.write(os.path.join(zone_dir, "bed_double.obj"))
    generated.append("residential/bed_double.obj")

    # Bunk bed (dwarven style)
    obj = OBJWriter("bed_bunk")
    obj.add_box(0, 0.15, 0, 1.0, 0.1, 2.0)      # Lower frame
    obj.add_box(0, 0.25, 0, 0.9, 0.08, 1.9)     # Lower mattress
    obj.add_box(0, 1.15, 0, 1.0, 0.1, 2.0)      # Upper frame
    obj.add_box(0, 1.25, 0, 0.9, 0.08, 1.9)     # Upper mattress
    obj.add_box(-0.45, 0.65, -0.95, 0.1, 1.3, 0.1)  # Post left-back
    obj.add_box(0.45, 0.65, -0.95, 0.1, 1.3, 0.1)   # Post right-back
    obj.add_box(-0.45, 0.65, 0.95, 0.1, 1.3, 0.1)   # Post left-front
    obj.add_box(0.45, 0.65, 0.95, 0.1, 1.3, 0.1)    # Post right-front
    obj.write(os.path.join(zone_dir, "bed_bunk.obj"))
    generated.append("residential/bed_bunk.obj")

    # --- HEARTHS ---

    # Small hearth
    obj = OBJWriter("hearth_small")
    obj.add_box(0, 0.4, 0, 1.5, 0.8, 1.0)       # Base
    obj.add_box(0, 1.0, -0.35, 1.5, 0.4, 0.3)   # Back wall
    obj.add_box(-0.6, 1.0, 0, 0.3, 0.4, 1.0)    # Left wall
    obj.add_box(0.6, 1.0, 0, 0.3, 0.4, 1.0)     # Right wall
    obj.write(os.path.join(zone_dir, "hearth_small.obj"))
    generated.append("residential/hearth_small.obj")

    # Large hearth with chimney
    obj = OBJWriter("hearth_large")
    obj.add_box(0, 0.5, 0, 2.5, 1.0, 1.5)       # Base
    obj.add_box(0, 1.5, -0.55, 2.5, 1.0, 0.4)   # Back wall
    obj.add_box(-1.05, 1.5, 0, 0.4, 1.0, 1.5)   # Left wall
    obj.add_box(1.05, 1.5, 0, 0.4, 1.0, 1.5)    # Right wall
    obj.add_box(0, 2.5, -0.4, 1.0, 1.0, 0.8)    # Chimney
    obj.write(os.path.join(zone_dir, "hearth_large.obj"))
    generated.append("residential/hearth_large.obj")

    # Cooking hearth
    obj = OBJWriter("hearth_cooking")
    obj.add_box(0, 0.5, 0, 2.0, 1.0, 1.2)
    obj.add_box(0, 1.1, 0, 1.6, 0.1, 0.8)       # Cooking grate
    obj.add_box(0, 1.5, -0.45, 2.0, 0.8, 0.3)
    obj.add_cylinder(0, 1.4, 0.3, 0.25, 0.4, 8) # Pot
    obj.write(os.path.join(zone_dir, "hearth_cooking.obj"))
    generated.append("residential/hearth_cooking.obj")

    # --- BARRELS ---

    # Standard barrel
    obj = OBJWriter("barrel_standard")
    obj.add_cylinder(0, 0.5, 0, 0.4, 1.0, 8)
    obj.add_box(0, 0.25, 0, 0.85, 0.08, 0.85)   # Lower band
    obj.add_box(0, 0.75, 0, 0.85, 0.08, 0.85)   # Upper band
    obj.write(os.path.join(zone_dir, "barrel_standard.obj"))
    generated.append("residential/barrel_standard.obj")

    # Small barrel
    obj = OBJWriter("barrel_small")
    obj.add_cylinder(0, 0.35, 0, 0.3, 0.7, 8)
    obj.add_box(0, 0.2, 0, 0.65, 0.06, 0.65)
    obj.add_box(0, 0.5, 0, 0.65, 0.06, 0.65)
    obj.write(os.path.join(zone_dir, "barrel_small.obj"))
    generated.append("residential/barrel_small.obj")

    # Barrel stack (3 barrels)
    obj = OBJWriter("barrel_stack")
    for i, pos in enumerate([(-0.5, 0.5, 0), (0.5, 0.5, 0), (0, 1.4, 0)]):
        obj.add_cylinder(pos[0], pos[1], pos[2], 0.4, 1.0, 8)
    obj.write(os.path.join(zone_dir, "barrel_stack.obj"))
    generated.append("residential/barrel_stack.obj")

    # Ale barrel (horizontal)
    obj = OBJWriter("barrel_ale")
    # Rotate by using different dimensions
    obj.add_cylinder(0, 0.4, 0, 0.4, 1.2, 8)
    obj.add_box(0, 0.4, -0.65, 0.1, 0.15, 0.1)  # Tap
    obj.add_box(-0.4, 0.0, 0, 0.15, 0.1, 0.8)   # Stand left
    obj.add_box(0.4, 0.0, 0, 0.15, 0.1, 0.8)    # Stand right
    obj.write(os.path.join(zone_dir, "barrel_ale.obj"))
    generated.append("residential/barrel_ale.obj")

    # --- TABLES ---

    # Small table
    obj = OBJWriter("table_small")
    obj.add_box(0, 0.45, 0, 1.0, 0.08, 1.0)     # Top
    obj.add_box(-0.4, 0.2, -0.4, 0.1, 0.4, 0.1) # Legs
    obj.add_box(0.4, 0.2, -0.4, 0.1, 0.4, 0.1)
    obj.add_box(-0.4, 0.2, 0.4, 0.1, 0.4, 0.1)
    obj.add_box(0.4, 0.2, 0.4, 0.1, 0.4, 0.1)
    obj.write(os.path.join(zone_dir, "table_small.obj"))
    generated.append("residential/table_small.obj")

    # Round table
    obj = OBJWriter("table_round")
    obj.add_cylinder(0, 0.45, 0, 0.6, 0.08, 8)  # Top
    obj.add_cylinder(0, 0.2, 0, 0.15, 0.4, 6)   # Center leg
    obj.write(os.path.join(zone_dir, "table_round.obj"))
    generated.append("residential/table_round.obj")

    # Long feast table
    obj = OBJWriter("table_feast")
    obj.add_box(0, 0.45, 0, 4.0, 0.1, 1.2)
    obj.add_box(-1.7, 0.2, 0, 0.15, 0.4, 1.0)   # Legs
    obj.add_box(1.7, 0.2, 0, 0.15, 0.4, 1.0)
    obj.add_box(0, 0.2, 0, 0.15, 0.4, 1.0)
    obj.write(os.path.join(zone_dir, "table_feast.obj"))
    generated.append("residential/table_feast.obj")

    # Work table
    obj = OBJWriter("table_work")
    obj.add_box(0, 0.5, 0, 1.5, 0.1, 0.8)
    obj.add_box(-0.65, 0.25, -0.3, 0.1, 0.5, 0.1)
    obj.add_box(0.65, 0.25, -0.3, 0.1, 0.5, 0.1)
    obj.add_box(-0.65, 0.25, 0.3, 0.1, 0.5, 0.1)
    obj.add_box(0.65, 0.25, 0.3, 0.1, 0.5, 0.1)
    obj.add_box(0, 0.15, 0, 1.3, 0.05, 0.6)     # Lower shelf
    obj.write(os.path.join(zone_dir, "table_work.obj"))
    generated.append("residential/table_work.obj")

    # --- BENCHES ---

    # Simple bench
    obj = OBJWriter("bench_simple")
    obj.add_box(0, 0.25, 0, 1.5, 0.08, 0.4)
    obj.add_box(-0.6, 0.12, 0, 0.1, 0.25, 0.35)
    obj.add_box(0.6, 0.12, 0, 0.1, 0.25, 0.35)
    obj.write(os.path.join(zone_dir, "bench_simple.obj"))
    generated.append("residential/bench_simple.obj")

    # Long bench
    obj = OBJWriter("bench_long")
    obj.add_box(0, 0.25, 0, 3.0, 0.08, 0.4)
    obj.add_box(-1.3, 0.12, 0, 0.1, 0.25, 0.35)
    obj.add_box(0, 0.12, 0, 0.1, 0.25, 0.35)
    obj.add_box(1.3, 0.12, 0, 0.1, 0.25, 0.35)
    obj.write(os.path.join(zone_dir, "bench_long.obj"))
    generated.append("residential/bench_long.obj")

    # Stone bench
    obj = OBJWriter("bench_stone")
    obj.add_box(0, 0.25, 0, 2.0, 0.15, 0.5)
    obj.add_box(-0.75, 0.15, 0, 0.3, 0.3, 0.45)
    obj.add_box(0.75, 0.15, 0, 0.3, 0.3, 0.45)
    obj.write(os.path.join(zone_dir, "bench_stone.obj"))
    generated.append("residential/bench_stone.obj")

    # Chair (dwarven style - sturdy)
    obj = OBJWriter("chair_dwarven")
    obj.add_box(0, 0.25, 0, 0.5, 0.08, 0.5)     # Seat
    obj.add_box(0, 0.55, -0.2, 0.5, 0.5, 0.08)  # Back
    obj.add_box(-0.2, 0.12, -0.2, 0.08, 0.25, 0.08)
    obj.add_box(0.2, 0.12, -0.2, 0.08, 0.25, 0.08)
    obj.add_box(-0.2, 0.12, 0.2, 0.08, 0.25, 0.08)
    obj.add_box(0.2, 0.12, 0.2, 0.08, 0.25, 0.08)
    obj.write(os.path.join(zone_dir, "chair_dwarven.obj"))
    generated.append("residential/chair_dwarven.obj")

    # Throne (for important dwarves)
    obj = OBJWriter("throne")
    obj.add_box(0, 0.3, 0, 0.9, 0.15, 0.8)      # Seat
    obj.add_box(0, 0.9, -0.35, 0.9, 1.0, 0.1)   # Back
    obj.add_box(-0.45, 0.5, 0.15, 0.1, 0.5, 0.5) # Armrest left
    obj.add_box(0.45, 0.5, 0.15, 0.1, 0.5, 0.5)  # Armrest right
    obj.write(os.path.join(zone_dir, "throne.obj"))
    generated.append("residential/throne.obj")

    # Wardrobe
    obj = OBJWriter("wardrobe")
    obj.add_box(0, 1.0, 0, 1.2, 2.0, 0.6)
    obj.add_box(-0.3, 1.0, 0.32, 0.08, 0.3, 0.05)  # Handle left
    obj.add_box(0.3, 1.0, 0.32, 0.08, 0.3, 0.05)   # Handle right
    obj.write(os.path.join(zone_dir, "wardrobe.obj"))
    generated.append("residential/wardrobe.obj")

    # Shelf
    obj = OBJWriter("shelf_wall")
    obj.add_box(0, 0, 0, 1.5, 0.08, 0.3)
    obj.add_box(-0.65, -0.15, -0.1, 0.1, 0.25, 0.1)
    obj.add_box(0.65, -0.15, -0.1, 0.1, 0.25, 0.1)
    obj.write(os.path.join(zone_dir, "shelf_wall.obj"))
    generated.append("residential/shelf_wall.obj")

    return generated


def generate_market_meshes(output_dir: str) -> List[str]:
    """Generate meshes for market zone: stalls, crates, sacks, signs, carts."""
    generated = []
    zone_dir = os.path.join(output_dir, "market")

    # --- STALLS ---

    # Basic market stall
    obj = OBJWriter("stall_basic")
    obj.add_box(0, 0.5, 0, 2.0, 0.1, 1.0)       # Counter
    obj.add_box(-0.9, 0.25, 0, 0.1, 0.5, 0.9)   # Leg left
    obj.add_box(0.9, 0.25, 0, 0.1, 0.5, 0.9)    # Leg right
    obj.add_box(0, 1.5, -0.4, 2.2, 0.08, 1.0)   # Awning
    obj.add_box(-1.0, 1.0, -0.4, 0.1, 1.0, 0.1) # Support left
    obj.add_box(1.0, 1.0, -0.4, 0.1, 1.0, 0.1)  # Support right
    obj.write(os.path.join(zone_dir, "stall_basic.obj"))
    generated.append("market/stall_basic.obj")

    # Covered stall
    obj = OBJWriter("stall_covered")
    obj.add_box(0, 0.5, 0, 2.5, 0.1, 1.2)
    obj.add_box(-1.1, 0.25, -0.5, 0.1, 0.5, 0.1)
    obj.add_box(1.1, 0.25, -0.5, 0.1, 0.5, 0.1)
    obj.add_box(-1.1, 0.25, 0.5, 0.1, 0.5, 0.1)
    obj.add_box(1.1, 0.25, 0.5, 0.1, 0.5, 0.1)
    obj.add_box(-1.1, 1.25, 0, 0.1, 1.5, 0.1)
    obj.add_box(1.1, 1.25, 0, 0.1, 1.5, 0.1)
    obj.add_wedge(0, 2.1, 0, 2.7, 0.6, 1.5, "z+")  # Roof
    obj.write(os.path.join(zone_dir, "stall_covered.obj"))
    generated.append("market/stall_covered.obj")

    # Food stall
    obj = OBJWriter("stall_food")
    obj.add_box(0, 0.5, 0, 2.0, 0.1, 1.0)
    obj.add_box(-0.9, 0.25, -0.4, 0.1, 0.5, 0.1)
    obj.add_box(0.9, 0.25, -0.4, 0.1, 0.5, 0.1)
    obj.add_box(-0.9, 0.25, 0.4, 0.1, 0.5, 0.1)
    obj.add_box(0.9, 0.25, 0.4, 0.1, 0.5, 0.1)
    obj.add_box(0, 0.65, 0, 0.8, 0.2, 0.6)      # Food display
    obj.write(os.path.join(zone_dir, "stall_food.obj"))
    generated.append("market/stall_food.obj")

    # Weapon stall with rack
    obj = OBJWriter("stall_weapons")
    obj.add_box(0, 0.5, 0, 2.5, 0.1, 1.0)
    obj.add_box(-1.1, 0.25, 0, 0.1, 0.5, 0.9)
    obj.add_box(1.1, 0.25, 0, 0.1, 0.5, 0.9)
    obj.add_box(0, 1.2, -0.4, 2.3, 0.1, 0.2)    # Weapon rack
    obj.add_box(0, 0.9, -0.4, 2.3, 0.1, 0.2)    # Lower rack
    obj.add_box(-1.0, 1.05, -0.4, 0.1, 0.8, 0.1)
    obj.add_box(1.0, 1.05, -0.4, 0.1, 0.8, 0.1)
    obj.write(os.path.join(zone_dir, "stall_weapons.obj"))
    generated.append("market/stall_weapons.obj")

    # --- CRATES ---

    # Small crate
    obj = OBJWriter("crate_small")
    obj.add_box(0, 0.25, 0, 0.5, 0.5, 0.5)
    obj.write(os.path.join(zone_dir, "crate_small.obj"))
    generated.append("market/crate_small.obj")

    # Medium crate
    obj = OBJWriter("crate_medium")
    obj.add_box(0, 0.4, 0, 0.8, 0.8, 0.8)
    obj.write(os.path.join(zone_dir, "crate_medium.obj"))
    generated.append("market/crate_medium.obj")

    # Large crate
    obj = OBJWriter("crate_large")
    obj.add_box(0, 0.5, 0, 1.0, 1.0, 1.0)
    obj.write(os.path.join(zone_dir, "crate_large.obj"))
    generated.append("market/crate_large.obj")

    # Crate stack
    obj = OBJWriter("crate_stack")
    obj.add_box(-0.4, 0.4, -0.3, 0.8, 0.8, 0.8)
    obj.add_box(0.4, 0.4, 0.2, 0.7, 0.7, 0.7)
    obj.add_box(0, 1.15, -0.1, 0.6, 0.6, 0.6)
    obj.write(os.path.join(zone_dir, "crate_stack.obj"))
    generated.append("market/crate_stack.obj")

    # Open crate
    obj = OBJWriter("crate_open")
    obj.add_box(0, 0.25, 0, 0.8, 0.5, 0.8)
    obj.add_box(0, 0.55, -0.35, 0.7, 0.1, 0.1)  # Back edge
    obj.add_box(-0.35, 0.55, 0, 0.1, 0.1, 0.7)  # Left edge
    obj.add_box(0.35, 0.55, 0, 0.1, 0.1, 0.7)   # Right edge
    obj.write(os.path.join(zone_dir, "crate_open.obj"))
    generated.append("market/crate_open.obj")

    # --- SACKS ---

    # Single sack
    obj = OBJWriter("sack_single")
    obj.add_cylinder(0, 0.3, 0, 0.25, 0.6, 6)
    obj.write(os.path.join(zone_dir, "sack_single.obj"))
    generated.append("market/sack_single.obj")

    # Sack pile
    obj = OBJWriter("sack_pile")
    obj.add_cylinder(-0.25, 0.25, -0.15, 0.25, 0.5, 6)
    obj.add_cylinder(0.25, 0.25, 0.1, 0.25, 0.5, 6)
    obj.add_cylinder(0, 0.25, 0.35, 0.22, 0.5, 6)
    obj.add_cylinder(0, 0.65, 0.05, 0.23, 0.45, 6)
    obj.write(os.path.join(zone_dir, "sack_pile.obj"))
    generated.append("market/sack_pile.obj")

    # Grain sack (larger, laying down)
    obj = OBJWriter("sack_grain")
    obj.add_box(0, 0.2, 0, 0.5, 0.4, 0.8)
    obj.write(os.path.join(zone_dir, "sack_grain.obj"))
    generated.append("market/sack_grain.obj")

    # --- SIGNS ---

    # Hanging sign
    obj = OBJWriter("sign_hanging")
    obj.add_box(0, 0, 0, 0.8, 0.5, 0.05)        # Sign board
    obj.add_box(0, 0.35, 0, 0.6, 0.06, 0.04)    # Top bracket
    obj.add_cylinder(-0.25, 0.4, 0, 0.02, 0.15, 4)  # Chain left
    obj.add_cylinder(0.25, 0.4, 0, 0.02, 0.15, 4)   # Chain right
    obj.write(os.path.join(zone_dir, "sign_hanging.obj"))
    generated.append("market/sign_hanging.obj")

    # Post sign
    obj = OBJWriter("sign_post")
    obj.add_box(0.4, 0.5, 0, 0.8, 0.4, 0.05)    # Sign
    obj.add_box(-0.1, 0.75, 0, 0.1, 1.5, 0.1)   # Post
    obj.write(os.path.join(zone_dir, "sign_post.obj"))
    generated.append("market/sign_post.obj")

    # Arrow sign
    obj = OBJWriter("sign_arrow")
    obj.add_box(0, 0.5, 0, 1.2, 0.3, 0.05)
    obj.add_box(-0.8, 0.75, 0, 0.1, 1.5, 0.1)
    obj.write(os.path.join(zone_dir, "sign_arrow.obj"))
    generated.append("market/sign_arrow.obj")

    # --- CARTS ---

    # Hand cart
    obj = OBJWriter("cart_hand")
    obj.add_box(0, 0.5, 0, 1.0, 0.6, 0.7)       # Body
    obj.add_cylinder(-0.3, 0.2, 0.5, 0.2, 0.1, 8)   # Wheel left
    obj.add_cylinder(0.3, 0.2, 0.5, 0.2, 0.1, 8)    # Wheel right
    obj.add_box(0, 0.6, -0.7, 0.1, 0.1, 0.7)    # Handle
    obj.write(os.path.join(zone_dir, "cart_hand.obj"))
    generated.append("market/cart_hand.obj")

    # Large wagon
    obj = OBJWriter("cart_wagon")
    obj.add_box(0, 0.6, 0, 2.0, 0.8, 1.2)       # Bed
    obj.add_box(0, 1.1, -0.55, 1.9, 0.2, 0.1)   # Front wall
    obj.add_box(0, 1.1, 0.55, 1.9, 0.2, 0.1)    # Back wall
    obj.add_box(-0.95, 1.1, 0, 0.1, 0.2, 1.1)   # Side left
    obj.add_box(0.95, 1.1, 0, 0.1, 0.2, 1.1)    # Side right
    obj.add_cylinder(-0.7, 0.25, 0.7, 0.25, 0.15, 8)
    obj.add_cylinder(0.7, 0.25, 0.7, 0.25, 0.15, 8)
    obj.add_cylinder(-0.7, 0.25, -0.7, 0.25, 0.15, 8)
    obj.add_cylinder(0.7, 0.25, -0.7, 0.25, 0.15, 8)
    obj.write(os.path.join(zone_dir, "cart_wagon.obj"))
    generated.append("market/cart_wagon.obj")

    # Mine cart (dwarven)
    obj = OBJWriter("cart_mine")
    obj.add_box(0, 0.4, 0, 0.8, 0.5, 1.0)
    obj.add_cylinder(-0.35, 0.15, -0.35, 0.15, 0.08, 8)
    obj.add_cylinder(0.35, 0.15, -0.35, 0.15, 0.08, 8)
    obj.add_cylinder(-0.35, 0.15, 0.35, 0.15, 0.08, 8)
    obj.add_cylinder(0.35, 0.15, 0.35, 0.15, 0.08, 8)
    obj.write(os.path.join(zone_dir, "cart_mine.obj"))
    generated.append("market/cart_mine.obj")

    # Wheelbarrow
    obj = OBJWriter("wheelbarrow")
    obj.add_box(0, 0.35, 0, 0.6, 0.4, 0.9)
    obj.add_cylinder(0, 0.15, 0.55, 0.15, 0.08, 8)
    obj.add_box(-0.25, 0.3, -0.6, 0.05, 0.05, 0.4)
    obj.add_box(0.25, 0.3, -0.6, 0.05, 0.05, 0.4)
    obj.write(os.path.join(zone_dir, "wheelbarrow.obj"))
    generated.append("market/wheelbarrow.obj")

    # Scales (for merchants)
    obj = OBJWriter("scales")
    obj.add_box(0, 0.15, 0, 0.4, 0.3, 0.3)      # Base
    obj.add_cylinder(0, 0.5, 0, 0.03, 0.7, 6)   # Post
    obj.add_box(0, 0.85, 0, 0.6, 0.03, 0.06)    # Beam
    obj.add_cylinder(-0.25, 0.7, 0, 0.1, 0.05, 6)  # Pan left
    obj.add_cylinder(0.25, 0.7, 0, 0.1, 0.05, 6)   # Pan right
    obj.write(os.path.join(zone_dir, "scales.obj"))
    generated.append("market/scales.obj")

    return generated


def generate_forge_meshes(output_dir: str) -> List[str]:
    """Generate meshes for forge zone: anvils, furnaces, bellows, tool racks."""
    generated = []
    zone_dir = os.path.join(output_dir, "forge")

    # --- ANVILS ---

    # Standard anvil
    obj = OBJWriter("anvil_standard")
    obj.add_box(0, 0.3, 0, 0.6, 0.6, 0.3)       # Base block
    obj.add_box(0, 0.7, 0, 0.8, 0.2, 0.35)      # Working surface
    obj.add_box(0.5, 0.7, 0, 0.25, 0.15, 0.2)   # Horn
    obj.write(os.path.join(zone_dir, "anvil_standard.obj"))
    generated.append("forge/anvil_standard.obj")

    # Large anvil
    obj = OBJWriter("anvil_large")
    obj.add_box(0, 0.35, 0, 0.8, 0.7, 0.4)
    obj.add_box(0, 0.8, 0, 1.0, 0.25, 0.45)
    obj.add_box(0.6, 0.8, 0, 0.3, 0.2, 0.25)
    obj.write(os.path.join(zone_dir, "anvil_large.obj"))
    generated.append("forge/anvil_large.obj")

    # Anvil on stump
    obj = OBJWriter("anvil_stump")
    obj.add_cylinder(0, 0.3, 0, 0.4, 0.6, 8)    # Stump
    obj.add_box(0, 0.7, 0, 0.6, 0.2, 0.3)
    obj.add_box(0, 0.9, 0, 0.75, 0.15, 0.32)
    obj.add_box(0.45, 0.9, 0, 0.2, 0.12, 0.18)
    obj.write(os.path.join(zone_dir, "anvil_stump.obj"))
    generated.append("forge/anvil_stump.obj")

    # --- FURNACES ---

    # Small furnace
    obj = OBJWriter("furnace_small")
    obj.add_box(0, 0.75, 0, 1.2, 1.5, 1.0)
    obj.add_box(0, 0.4, 0.55, 0.5, 0.4, 0.15)   # Door
    obj.add_cylinder(0, 1.8, 0, 0.25, 0.6, 6)   # Chimney
    obj.write(os.path.join(zone_dir, "furnace_small.obj"))
    generated.append("forge/furnace_small.obj")

    # Large furnace
    obj = OBJWriter("furnace_large")
    obj.add_box(0, 1.0, 0, 2.0, 2.0, 1.5)
    obj.add_box(0, 0.5, 0.8, 0.8, 0.6, 0.2)     # Door
    obj.add_cylinder(-0.5, 2.3, 0, 0.3, 0.6, 6)
    obj.add_cylinder(0.5, 2.3, 0, 0.3, 0.6, 6)
    obj.write(os.path.join(zone_dir, "furnace_large.obj"))
    generated.append("forge/furnace_large.obj")

    # Smelter (dwarven)
    obj = OBJWriter("smelter")
    obj.add_box(0, 1.25, 0, 2.5, 2.5, 2.0)
    obj.add_box(0, 0.3, 1.1, 1.0, 0.6, 0.3)     # Front opening
    obj.add_cylinder(0, 2.8, 0, 0.5, 0.6, 8)    # Main chimney
    obj.add_box(0, 0.5, -0.9, 0.6, 0.4, 0.2)    # Tap hole
    obj.write(os.path.join(zone_dir, "smelter.obj"))
    generated.append("forge/smelter.obj")

    # Kiln
    obj = OBJWriter("kiln")
    obj.add_cylinder(0, 0.6, 0, 0.8, 1.2, 8)
    obj.add_box(0, 0.4, 0.7, 0.4, 0.4, 0.2)     # Door
    obj.write(os.path.join(zone_dir, "kiln.obj"))
    generated.append("forge/kiln.obj")

    # --- BELLOWS ---

    # Hand bellows
    obj = OBJWriter("bellows_hand")
    obj.add_box(0, 0.15, 0, 0.5, 0.2, 0.8)      # Body
    obj.add_box(0, 0.3, -0.35, 0.4, 0.1, 0.2)   # Top plate
    obj.add_box(0, 0.15, 0.45, 0.15, 0.1, 0.15) # Nozzle
    obj.write(os.path.join(zone_dir, "bellows_hand.obj"))
    generated.append("forge/bellows_hand.obj")

    # Large bellows
    obj = OBJWriter("bellows_large")
    obj.add_box(0, 0.5, 0, 1.0, 0.8, 1.5)
    obj.add_box(0, 0.9, -0.5, 0.8, 0.1, 0.6)
    obj.add_box(0, 0.5, 0.85, 0.3, 0.25, 0.3)
    obj.add_box(0.6, 0.5, -0.4, 0.15, 0.3, 0.1) # Handle
    obj.write(os.path.join(zone_dir, "bellows_large.obj"))
    generated.append("forge/bellows_large.obj")

    # Floor bellows (foot operated)
    obj = OBJWriter("bellows_floor")
    obj.add_box(0, 0.3, 0, 0.8, 0.5, 1.2)
    obj.add_box(0, 0.55, 0, 0.6, 0.05, 1.0)     # Top plate
    obj.add_box(0, 0.3, 0.7, 0.2, 0.2, 0.2)     # Nozzle
    obj.add_box(0, 0.1, -0.5, 0.4, 0.1, 0.3)    # Foot pedal
    obj.write(os.path.join(zone_dir, "bellows_floor.obj"))
    generated.append("forge/bellows_floor.obj")

    # --- TOOL RACKS ---

    # Wall tool rack
    obj = OBJWriter("rack_wall")
    obj.add_box(0, 0, 0, 1.5, 0.1, 0.15)        # Main board
    obj.add_box(0, -0.15, 0.05, 1.4, 0.05, 0.1) # Lower hook bar
    obj.add_box(-0.5, -0.2, 0.08, 0.08, 0.15, 0.05)  # Hook 1
    obj.add_box(0, -0.2, 0.08, 0.08, 0.15, 0.05)     # Hook 2
    obj.add_box(0.5, -0.2, 0.08, 0.08, 0.15, 0.05)   # Hook 3
    obj.write(os.path.join(zone_dir, "rack_wall.obj"))
    generated.append("forge/rack_wall.obj")

    # Standing tool rack
    obj = OBJWriter("rack_standing")
    obj.add_box(0, 0.75, 0, 0.1, 1.5, 0.6)      # Vertical board
    obj.add_box(0, 0.1, 0, 0.6, 0.1, 0.6)       # Base
    obj.add_box(0, 0.5, 0.35, 1.0, 0.08, 0.1)   # Cross bar 1
    obj.add_box(0, 1.0, 0.35, 1.0, 0.08, 0.1)   # Cross bar 2
    obj.write(os.path.join(zone_dir, "rack_standing.obj"))
    generated.append("forge/rack_standing.obj")

    # Weapon rack
    obj = OBJWriter("rack_weapons")
    obj.add_box(0, 0.1, 0, 1.8, 0.2, 0.5)       # Base
    obj.add_box(-0.8, 0.75, 0, 0.1, 1.3, 0.1)   # Post left
    obj.add_box(0.8, 0.75, 0, 0.1, 1.3, 0.1)    # Post right
    obj.add_box(0, 0.5, 0.2, 1.7, 0.08, 0.1)    # Lower bar
    obj.add_box(0, 1.2, 0.2, 1.7, 0.08, 0.1)    # Upper bar
    obj.write(os.path.join(zone_dir, "rack_weapons.obj"))
    generated.append("forge/rack_weapons.obj")

    # Hammer (lying down)
    obj = OBJWriter("hammer")
    obj.add_box(0, 0.1, 0, 0.2, 0.15, 0.15)     # Head
    obj.add_box(0.25, 0.08, 0, 0.4, 0.05, 0.05) # Handle
    obj.write(os.path.join(zone_dir, "hammer.obj"))
    generated.append("forge/hammer.obj")

    # Tongs
    obj = OBJWriter("tongs")
    obj.add_box(-0.02, 0.03, 0, 0.04, 0.06, 0.6)
    obj.add_box(0.02, 0.03, 0, 0.04, 0.06, 0.6)
    obj.add_box(0, 0.04, 0.25, 0.06, 0.04, 0.06)  # Pivot
    obj.write(os.path.join(zone_dir, "tongs.obj"))
    generated.append("forge/tongs.obj")

    # Quench tank
    obj = OBJWriter("quench_tank")
    obj.add_box(0, 0.4, 0, 1.0, 0.8, 0.6)
    obj.add_box(0, 0.85, 0, 0.9, 0.05, 0.5)     # Water surface
    obj.write(os.path.join(zone_dir, "quench_tank.obj"))
    generated.append("forge/quench_tank.obj")

    # Grinding wheel
    obj = OBJWriter("grinding_wheel")
    obj.add_cylinder(0, 0.5, 0, 0.4, 0.15, 8)   # Wheel
    obj.add_box(0, 0.25, 0, 0.1, 0.5, 0.5)      # Stand
    obj.add_box(0, 0.5, 0.4, 0.4, 0.08, 0.1)    # Crank
    obj.write(os.path.join(zone_dir, "grinding_wheel.obj"))
    generated.append("forge/grinding_wheel.obj")

    # Coal pile
    obj = OBJWriter("coal_pile")
    obj.add_pyramid(0, 0.2, 0, 1.0, 0.4, 6)
    obj.write(os.path.join(zone_dir, "coal_pile.obj"))
    generated.append("forge/coal_pile.obj")

    # Ingot stack
    obj = OBJWriter("ingot_stack")
    obj.add_box(-0.15, 0.05, -0.1, 0.25, 0.1, 0.5)
    obj.add_box(0.15, 0.05, 0, 0.25, 0.1, 0.5)
    obj.add_box(0, 0.15, -0.05, 0.25, 0.1, 0.5)
    obj.write(os.path.join(zone_dir, "ingot_stack.obj"))
    generated.append("forge/ingot_stack.obj")

    return generated


def generate_bridge_meshes(output_dir: str) -> List[str]:
    """Generate meshes for bridge zone: sections, pillars, guard posts, dwarf statues."""
    generated = []
    zone_dir = os.path.join(output_dir, "bridge")

    # --- BRIDGE SECTIONS ---

    # Straight bridge section
    obj = OBJWriter("bridge_straight")
    obj.add_box(0, 0, 0, 4.0, 0.4, 8.0)         # Deck
    obj.add_box(-1.9, 0.5, 0, 0.2, 0.6, 8.0)    # Railing left
    obj.add_box(1.9, 0.5, 0, 0.2, 0.6, 8.0)     # Railing right
    obj.write(os.path.join(zone_dir, "bridge_straight.obj"))
    generated.append("bridge/bridge_straight.obj")

    # Wide bridge section
    obj = OBJWriter("bridge_wide")
    obj.add_box(0, 0, 0, 6.0, 0.4, 8.0)
    obj.add_box(-2.9, 0.5, 0, 0.2, 0.6, 8.0)
    obj.add_box(2.9, 0.5, 0, 0.2, 0.6, 8.0)
    obj.write(os.path.join(zone_dir, "bridge_wide.obj"))
    generated.append("bridge/bridge_wide.obj")

    # Bridge with pillars
    obj = OBJWriter("bridge_pillared")
    obj.add_box(0, 0, 0, 4.0, 0.4, 8.0)
    obj.add_box(-1.9, 0.5, 0, 0.2, 0.6, 8.0)
    obj.add_box(1.9, 0.5, 0, 0.2, 0.6, 8.0)
    obj.add_box(-1.9, 1.0, -3.5, 0.4, 0.6, 0.4)  # Pillar left front
    obj.add_box(1.9, 1.0, -3.5, 0.4, 0.6, 0.4)   # Pillar right front
    obj.add_box(-1.9, 1.0, 3.5, 0.4, 0.6, 0.4)   # Pillar left back
    obj.add_box(1.9, 1.0, 3.5, 0.4, 0.6, 0.4)    # Pillar right back
    obj.write(os.path.join(zone_dir, "bridge_pillared.obj"))
    generated.append("bridge/bridge_pillared.obj")

    # Bridge ramp
    obj = OBJWriter("bridge_ramp")
    obj.add_wedge(0, 0.5, 0, 4.0, 1.0, 6.0, "z+")
    obj.add_box(-1.9, 0.75, 0, 0.2, 0.5, 6.0)
    obj.add_box(1.9, 0.75, 0, 0.2, 0.5, 6.0)
    obj.write(os.path.join(zone_dir, "bridge_ramp.obj"))
    generated.append("bridge/bridge_ramp.obj")

    # --- PILLARS ---

    # Simple pillar
    obj = OBJWriter("pillar_simple")
    obj.add_cylinder(0, 2.0, 0, 0.5, 4.0, 8)
    obj.write(os.path.join(zone_dir, "pillar_simple.obj"))
    generated.append("bridge/pillar_simple.obj")

    # Ornate pillar
    obj = OBJWriter("pillar_ornate")
    obj.add_box(0, 0.15, 0, 1.0, 0.3, 1.0)      # Base
    obj.add_cylinder(0, 2.0, 0, 0.45, 3.5, 8)   # Shaft
    obj.add_box(0, 3.85, 0, 1.0, 0.3, 1.0)      # Capital
    obj.write(os.path.join(zone_dir, "pillar_ornate.obj"))
    generated.append("bridge/pillar_ornate.obj")

    # Thick support pillar
    obj = OBJWriter("pillar_support")
    obj.add_box(0, 0.25, 0, 1.2, 0.5, 1.2)      # Base
    obj.add_box(0, 2.5, 0, 1.0, 4.5, 1.0)       # Main shaft
    obj.add_box(0, 4.85, 0, 1.3, 0.3, 1.3)      # Top
    obj.write(os.path.join(zone_dir, "pillar_support.obj"))
    generated.append("bridge/pillar_support.obj")

    # Ruined pillar
    obj = OBJWriter("pillar_ruined")
    obj.add_box(0, 0.15, 0, 1.0, 0.3, 1.0)
    obj.add_cylinder(0, 1.2, 0, 0.45, 2.0, 8)
    obj.add_box(0.2, 2.1, 0.1, 0.4, 0.3, 0.3)   # Broken top
    obj.write(os.path.join(zone_dir, "pillar_ruined.obj"))
    generated.append("bridge/pillar_ruined.obj")

    # --- GUARD POSTS ---

    # Guard post
    obj = OBJWriter("guard_post")
    obj.add_box(0, 0.75, 0, 2.0, 1.5, 2.0)      # Base
    obj.add_box(0, 2.0, 0, 1.8, 1.0, 1.8)       # Upper section
    obj.add_box(-0.85, 2.0, 0, 0.1, 1.2, 1.6)   # Wall left
    obj.add_box(0.85, 2.0, 0, 0.1, 1.2, 1.6)    # Wall right
    obj.add_box(0, 2.0, -0.85, 1.6, 1.2, 0.1)   # Wall back
    obj.write(os.path.join(zone_dir, "guard_post.obj"))
    generated.append("bridge/guard_post.obj")

    # Watchtower base
    obj = OBJWriter("watchtower_base")
    obj.add_box(0, 1.5, 0, 3.0, 3.0, 3.0)
    obj.add_box(0, 0.5, 1.6, 0.8, 1.0, 0.2)     # Door
    obj.write(os.path.join(zone_dir, "watchtower_base.obj"))
    generated.append("bridge/watchtower_base.obj")

    # Checkpoint barrier
    obj = OBJWriter("checkpoint")
    obj.add_box(-1.5, 0.5, 0, 0.4, 1.0, 0.4)    # Post left
    obj.add_box(1.5, 0.5, 0, 0.4, 1.0, 0.4)     # Post right
    obj.add_box(0, 0.7, 0, 2.8, 0.15, 0.1)      # Barrier beam
    obj.write(os.path.join(zone_dir, "checkpoint.obj"))
    generated.append("bridge/checkpoint.obj")

    # --- DWARF STATUES ---

    # Dwarf warrior statue
    obj = OBJWriter("statue_warrior")
    obj.add_box(0, 0.25, 0, 1.2, 0.5, 1.2)      # Base
    obj.add_box(0, 0.8, 0, 0.6, 0.6, 0.4)       # Legs/lower body
    obj.add_box(0, 1.3, 0, 0.7, 0.5, 0.45)      # Torso
    obj.add_box(0, 1.7, 0, 0.4, 0.35, 0.35)     # Head
    obj.add_box(-0.5, 1.2, 0, 0.25, 0.6, 0.2)   # Left arm
    obj.add_box(0.5, 1.2, 0, 0.25, 0.6, 0.2)    # Right arm (axe side)
    obj.add_box(0.6, 0.8, 0.2, 0.1, 1.2, 0.1)   # Axe handle
    obj.add_box(0.6, 1.5, 0.25, 0.08, 0.4, 0.3) # Axe head
    obj.write(os.path.join(zone_dir, "statue_warrior.obj"))
    generated.append("bridge/statue_warrior.obj")

    # Dwarf king statue
    obj = OBJWriter("statue_king")
    obj.add_box(0, 0.3, 0, 1.5, 0.6, 1.5)       # Throne base
    obj.add_box(0, 1.0, 0, 0.7, 0.8, 0.5)       # Lower body
    obj.add_box(0, 1.6, 0, 0.8, 0.6, 0.5)       # Torso
    obj.add_box(0, 2.1, 0, 0.45, 0.4, 0.4)      # Head
    obj.add_box(0, 2.35, 0, 0.5, 0.15, 0.5)     # Crown
    obj.add_box(0, 1.9, -0.35, 0.9, 0.8, 0.1)   # Throne back
    obj.add_box(-0.5, 1.3, 0, 0.3, 0.6, 0.2)    # Arms on armrests
    obj.add_box(0.5, 1.3, 0, 0.3, 0.6, 0.2)
    obj.write(os.path.join(zone_dir, "statue_king.obj"))
    generated.append("bridge/statue_king.obj")

    # Dwarf miner statue
    obj = OBJWriter("statue_miner")
    obj.add_box(0, 0.2, 0, 1.0, 0.4, 1.0)
    obj.add_box(0, 0.7, 0, 0.55, 0.6, 0.4)
    obj.add_box(0, 1.2, 0, 0.65, 0.5, 0.4)
    obj.add_box(0, 1.6, 0, 0.4, 0.35, 0.35)
    obj.add_box(-0.45, 1.1, 0.15, 0.2, 0.5, 0.15)
    obj.add_box(0.45, 1.0, 0.2, 0.15, 0.8, 0.15)  # Pickaxe handle
    obj.add_box(0.45, 1.45, 0.3, 0.1, 0.2, 0.35)  # Pickaxe head
    obj.write(os.path.join(zone_dir, "statue_miner.obj"))
    generated.append("bridge/statue_miner.obj")

    # Memorial obelisk
    obj = OBJWriter("obelisk")
    obj.add_box(0, 0.25, 0, 1.2, 0.5, 1.2)      # Base
    obj.add_box(0, 2.0, 0, 0.6, 3.0, 0.6)       # Shaft
    obj.add_pyramid(0, 3.75, 0, 0.7, 0.5, 4)    # Top
    obj.write(os.path.join(zone_dir, "obelisk.obj"))
    generated.append("bridge/obelisk.obj")

    # Torch sconce
    obj = OBJWriter("torch_sconce")
    obj.add_box(0, 0, -0.15, 0.2, 0.2, 0.3)     # Wall mount
    obj.add_box(0, 0.15, 0, 0.1, 0.3, 0.1)      # Bracket
    obj.add_cylinder(0, 0.45, 0, 0.06, 0.3, 6)  # Torch
    obj.write(os.path.join(zone_dir, "torch_sconce.obj"))
    generated.append("bridge/torch_sconce.obj")

    return generated


def generate_vault_meshes(output_dir: str) -> List[str]:
    """Generate meshes for vault zone: vault doors, treasure piles, chests, rune wards."""
    generated = []
    zone_dir = os.path.join(output_dir, "vault")

    # --- VAULT DOORS ---

    # Simple vault door
    obj = OBJWriter("door_vault_simple")
    obj.add_box(0, 1.5, 0, 2.5, 3.0, 0.4)       # Door
    obj.add_cylinder(-0.8, 1.5, 0.25, 0.15, 0.15, 8)  # Handle
    obj.add_box(0, 1.5, 0.15, 0.4, 0.4, 0.15)   # Lock plate
    obj.write(os.path.join(zone_dir, "door_vault_simple.obj"))
    generated.append("vault/door_vault_simple.obj")

    # Heavy vault door
    obj = OBJWriter("door_vault_heavy")
    obj.add_box(0, 1.75, 0, 3.0, 3.5, 0.6)
    obj.add_cylinder(-1.0, 1.75, 0.35, 0.2, 0.2, 8)
    obj.add_box(0, 1.75, 0.25, 0.6, 0.6, 0.2)
    obj.add_box(-1.3, 1.75, 0.1, 0.15, 2.5, 0.15)  # Hinge left
    obj.add_box(-1.3, 0.4, 0.1, 0.15, 0.3, 0.15)
    obj.add_box(-1.3, 3.1, 0.1, 0.15, 0.3, 0.15)
    obj.write(os.path.join(zone_dir, "door_vault_heavy.obj"))
    generated.append("vault/door_vault_heavy.obj")

    # Ornate vault door
    obj = OBJWriter("door_vault_ornate")
    obj.add_box(0, 1.75, 0, 3.5, 3.5, 0.5)
    obj.add_box(0, 1.75, 0.28, 2.8, 2.8, 0.08)  # Decorative panel
    obj.add_cylinder(0, 1.75, 0.35, 0.5, 0.2, 8)  # Central lock
    obj.add_box(-1.55, 1.75, 0.15, 0.2, 2.8, 0.15)
    obj.add_box(-1.55, 0.5, 0.15, 0.2, 0.4, 0.15)
    obj.add_box(-1.55, 3.0, 0.15, 0.2, 0.4, 0.15)
    obj.write(os.path.join(zone_dir, "door_vault_ornate.obj"))
    generated.append("vault/door_vault_ornate.obj")

    # Gate portcullis
    obj = OBJWriter("gate_portcullis")
    obj.add_box(0, 1.75, 0, 4.0, 3.5, 0.15)     # Frame (simplified)
    for x in [-1.5, -0.75, 0, 0.75, 1.5]:
        obj.add_box(x, 1.75, 0, 0.1, 3.5, 0.1)  # Bars
    obj.add_box(0, 0.25, 0, 3.2, 0.1, 0.1)      # Bottom bar
    obj.add_box(0, 1.75, 0, 3.2, 0.1, 0.1)      # Middle bar
    obj.add_box(0, 3.25, 0, 3.2, 0.1, 0.1)      # Top bar
    obj.write(os.path.join(zone_dir, "gate_portcullis.obj"))
    generated.append("vault/gate_portcullis.obj")

    # --- TREASURE PILES ---

    # Small coin pile
    obj = OBJWriter("treasure_coins_small")
    obj.add_pyramid(0, 0.1, 0, 0.6, 0.2, 8)
    obj.write(os.path.join(zone_dir, "treasure_coins_small.obj"))
    generated.append("vault/treasure_coins_small.obj")

    # Large coin pile
    obj = OBJWriter("treasure_coins_large")
    obj.add_pyramid(-0.2, 0.15, 0, 1.0, 0.3, 8)
    obj.add_pyramid(0.3, 0.1, 0.2, 0.7, 0.2, 8)
    obj.write(os.path.join(zone_dir, "treasure_coins_large.obj"))
    generated.append("vault/treasure_coins_large.obj")

    # Mixed treasure pile
    obj = OBJWriter("treasure_mixed")
    obj.add_pyramid(0, 0.2, 0, 1.2, 0.4, 8)     # Coins
    obj.add_box(-0.4, 0.15, 0.4, 0.3, 0.2, 0.5) # Goblet (simplified)
    obj.add_box(0.5, 0.1, -0.3, 0.4, 0.2, 0.2)  # Small item
    obj.write(os.path.join(zone_dir, "treasure_mixed.obj"))
    generated.append("vault/treasure_mixed.obj")

    # Crown on cushion
    obj = OBJWriter("treasure_crown")
    obj.add_box(0, 0.1, 0, 0.5, 0.2, 0.5)       # Cushion
    obj.add_cylinder(0, 0.3, 0, 0.15, 0.15, 8)  # Crown base
    obj.add_pyramid(0, 0.45, 0, 0.35, 0.15, 4)  # Crown points
    obj.write(os.path.join(zone_dir, "treasure_crown.obj"))
    generated.append("vault/treasure_crown.obj")

    # Gem pile
    obj = OBJWriter("treasure_gems")
    obj.add_pyramid(0, 0.1, 0, 0.4, 0.2, 6)
    obj.add_pyramid(0.15, 0.08, 0.15, 0.25, 0.15, 6)
    obj.add_pyramid(-0.1, 0.07, -0.12, 0.2, 0.12, 6)
    obj.write(os.path.join(zone_dir, "treasure_gems.obj"))
    generated.append("vault/treasure_gems.obj")

    # --- CHESTS ---

    # Small chest
    obj = OBJWriter("chest_small")
    obj.add_box(0, 0.2, 0, 0.5, 0.4, 0.35)
    obj.add_box(0, 0.45, 0, 0.55, 0.1, 0.4)     # Lid
    obj.add_box(0, 0.25, 0.2, 0.15, 0.1, 0.05)  # Lock
    obj.write(os.path.join(zone_dir, "chest_small.obj"))
    generated.append("vault/chest_small.obj")

    # Medium chest
    obj = OBJWriter("chest_medium")
    obj.add_box(0, 0.25, 0, 0.8, 0.5, 0.5)
    obj.add_box(0, 0.55, 0, 0.85, 0.12, 0.55)
    obj.add_box(0, 0.3, 0.28, 0.2, 0.15, 0.05)
    obj.add_box(-0.35, 0.25, 0, 0.1, 0.45, 0.45)  # Metal band left
    obj.add_box(0.35, 0.25, 0, 0.1, 0.45, 0.45)   # Metal band right
    obj.write(os.path.join(zone_dir, "chest_medium.obj"))
    generated.append("vault/chest_medium.obj")

    # Large treasure chest
    obj = OBJWriter("chest_large")
    obj.add_box(0, 0.35, 0, 1.2, 0.7, 0.7)
    obj.add_box(0, 0.75, 0, 1.25, 0.15, 0.75)
    obj.add_box(0, 0.4, 0.4, 0.25, 0.2, 0.08)
    obj.add_box(-0.5, 0.35, 0, 0.12, 0.6, 0.65)
    obj.add_box(0.5, 0.35, 0, 0.12, 0.6, 0.65)
    obj.add_box(0, 0.35, 0, 0.12, 0.6, 0.65)    # Center band
    obj.write(os.path.join(zone_dir, "chest_large.obj"))
    generated.append("vault/chest_large.obj")

    # Open chest (with coins spilling)
    obj = OBJWriter("chest_open")
    obj.add_box(0, 0.25, 0, 0.8, 0.5, 0.5)
    obj.add_box(0, 0.55, -0.25, 0.85, 0.12, 0.55)  # Lid (rotated back)
    obj.add_pyramid(0, 0.4, 0.1, 0.5, 0.2, 6)   # Coins inside
    obj.add_pyramid(0.2, 0.1, 0.4, 0.3, 0.15, 6)  # Spilled coins
    obj.write(os.path.join(zone_dir, "chest_open.obj"))
    generated.append("vault/chest_open.obj")

    # --- RUNE WARDS ---

    # Floor rune ward
    obj = OBJWriter("rune_floor")
    obj.add_cylinder(0, 0.02, 0, 1.0, 0.04, 8)  # Outer ring
    obj.add_cylinder(0, 0.03, 0, 0.7, 0.04, 6)  # Inner pattern
    obj.add_pyramid(0, 0.05, 0, 0.3, 0.1, 4)    # Center element
    obj.write(os.path.join(zone_dir, "rune_floor.obj"))
    generated.append("vault/rune_floor.obj")

    # Wall rune ward
    obj = OBJWriter("rune_wall")
    obj.add_box(0, 0, 0.01, 1.0, 1.0, 0.05)     # Backing
    obj.add_cylinder(0, 0, 0.05, 0.4, 0.03, 6)  # Inner circle
    obj.add_box(-0.35, 0, 0.05, 0.7, 0.08, 0.02)  # Horizontal line
    obj.add_box(0, -0.35, 0.05, 0.08, 0.7, 0.02)  # Vertical line
    obj.write(os.path.join(zone_dir, "rune_wall.obj"))
    generated.append("vault/rune_wall.obj")

    # Protective pillar ward
    obj = OBJWriter("rune_pillar")
    obj.add_box(0, 0.15, 0, 0.5, 0.3, 0.5)      # Base
    obj.add_cylinder(0, 0.75, 0, 0.2, 1.0, 6)   # Pillar
    obj.add_pyramid(0, 1.4, 0, 0.4, 0.3, 4)     # Top
    obj.write(os.path.join(zone_dir, "rune_pillar.obj"))
    generated.append("vault/rune_pillar.obj")

    # Vault pedestal
    obj = OBJWriter("pedestal")
    obj.add_box(0, 0.2, 0, 0.8, 0.4, 0.8)       # Base
    obj.add_box(0, 0.6, 0, 0.6, 0.4, 0.6)       # Middle
    obj.add_box(0, 0.9, 0, 0.7, 0.2, 0.7)       # Top
    obj.write(os.path.join(zone_dir, "pedestal.obj"))
    generated.append("vault/pedestal.obj")

    # Vault safe
    obj = OBJWriter("safe")
    obj.add_box(0, 0.5, 0, 0.8, 1.0, 0.6)
    obj.add_cylinder(-0.25, 0.5, 0.32, 0.15, 0.08, 8)  # Dial
    obj.add_box(0.2, 0.5, 0.32, 0.15, 0.08, 0.05)      # Handle
    obj.write(os.path.join(zone_dir, "safe.obj"))
    generated.append("vault/safe.obj")

    # Strongbox
    obj = OBJWriter("strongbox")
    obj.add_box(0, 0.15, 0, 0.4, 0.3, 0.3)
    obj.add_box(0, 0.32, 0, 0.42, 0.05, 0.32)   # Lid
    obj.add_box(0, 0.18, 0.17, 0.1, 0.08, 0.03) # Lock
    obj.add_box(-0.18, 0.15, 0, 0.04, 0.25, 0.28)  # Band
    obj.add_box(0.18, 0.15, 0, 0.04, 0.25, 0.28)
    obj.write(os.path.join(zone_dir, "strongbox.obj"))
    generated.append("vault/strongbox.obj")

    return generated


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

ZONE_GENERATORS = {
    "residential": generate_residential_meshes,
    "market": generate_market_meshes,
    "forge": generate_forge_meshes,
    "bridge": generate_bridge_meshes,
    "vault": generate_vault_meshes,
}

MESH_CATALOG = {
    "residential": [
        "bed_single", "bed_double", "bed_bunk",
        "hearth_small", "hearth_large", "hearth_cooking",
        "barrel_standard", "barrel_small", "barrel_stack", "barrel_ale",
        "table_small", "table_round", "table_feast", "table_work",
        "bench_simple", "bench_long", "bench_stone", "chair_dwarven", "throne",
        "wardrobe", "shelf_wall"
    ],
    "market": [
        "stall_basic", "stall_covered", "stall_food", "stall_weapons",
        "crate_small", "crate_medium", "crate_large", "crate_stack", "crate_open",
        "sack_single", "sack_pile", "sack_grain",
        "sign_hanging", "sign_post", "sign_arrow",
        "cart_hand", "cart_wagon", "cart_mine", "wheelbarrow", "scales"
    ],
    "forge": [
        "anvil_standard", "anvil_large", "anvil_stump",
        "furnace_small", "furnace_large", "smelter", "kiln",
        "bellows_hand", "bellows_large", "bellows_floor",
        "rack_wall", "rack_standing", "rack_weapons",
        "hammer", "tongs", "quench_tank", "grinding_wheel", "coal_pile", "ingot_stack"
    ],
    "bridge": [
        "bridge_straight", "bridge_wide", "bridge_pillared", "bridge_ramp",
        "pillar_simple", "pillar_ornate", "pillar_support", "pillar_ruined",
        "guard_post", "watchtower_base", "checkpoint",
        "statue_warrior", "statue_king", "statue_miner", "obelisk", "torch_sconce"
    ],
    "vault": [
        "door_vault_simple", "door_vault_heavy", "door_vault_ornate", "gate_portcullis",
        "treasure_coins_small", "treasure_coins_large", "treasure_mixed", "treasure_crown", "treasure_gems",
        "chest_small", "chest_medium", "chest_large", "chest_open",
        "rune_floor", "rune_wall", "rune_pillar", "pedestal", "safe", "strongbox"
    ]
}


def list_catalog():
    """Print the mesh catalog organized by zone."""
    print("\n=== DWARVEN STRONGHOLD MESH CATALOG ===\n")
    total = 0
    for zone, meshes in MESH_CATALOG.items():
        print(f"[{zone.upper()}] ({len(meshes)} meshes)")
        for mesh in meshes:
            print(f"  - {mesh}.obj")
        print()
        total += len(meshes)
    print(f"TOTAL: {total} meshes")


def main():
    parser = argparse.ArgumentParser(
        description="Generate dwarven stronghold OBJ meshes for Kazan-Dun",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python dwarven_stronghold_gen.py --list
  python dwarven_stronghold_gen.py --zone all --output ./assets/meshes/dwarven/
  python dwarven_stronghold_gen.py --zone forge --output ./assets/meshes/dwarven/
        """
    )
    parser.add_argument(
        "--zone",
        choices=["all", "residential", "market", "forge", "bridge", "vault"],
        help="Zone to generate meshes for (default: all)"
    )
    parser.add_argument(
        "--output",
        default="./assets/meshes/dwarven/",
        help="Output directory for OBJ files"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List all available meshes without generating"
    )

    args = parser.parse_args()

    if args.list:
        list_catalog()
        return

    if not args.zone:
        parser.print_help()
        return

    output_dir = os.path.abspath(args.output)
    print(f"Generating meshes to: {output_dir}")

    all_generated = []

    if args.zone == "all":
        for zone_name, generator in ZONE_GENERATORS.items():
            print(f"\nGenerating {zone_name} zone...")
            generated = generator(output_dir)
            all_generated.extend(generated)
            print(f"  Generated {len(generated)} meshes")
    else:
        generator = ZONE_GENERATORS[args.zone]
        print(f"\nGenerating {args.zone} zone...")
        generated = generator(output_dir)
        all_generated.extend(generated)
        print(f"  Generated {len(generated)} meshes")

    print(f"\n=== COMPLETE ===")
    print(f"Total meshes generated: {len(all_generated)}")
    print(f"Output directory: {output_dir}")


if __name__ == "__main__":
    main()
