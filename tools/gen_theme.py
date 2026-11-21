"""Themes de l'interface "carnet de reves" (a relancer apres tools/gen_ui.py si les marges changent).

Lancer depuis la racine du projet : python tools/gen_theme.py
Ecrit :
  assets/ui/theme.tres        theme du projet : papier (boutons, panneaux, HUD, messages), police
                              pixel Jersey ; les textes poses sur le jeu sont clairs, cernes d'encre.
  assets/ui/paper_theme.tres  a poser sur un panneau de papier (Paper.apply) : textes a l'encre.
Les textures (assets/ui/notebook/) sont dessinees a 2 pixels du jeu par pixel d'art : les marges
ci-dessous sont en pixels du jeu.
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
INK = "Color(0.17, 0.13, 0.25, 1)"
INK_SOFT = "Color(0.36, 0.31, 0.47, 1)"
CREAM = "Color(0.97, 0.94, 0.86, 1)"
BODY_SIZE = 15   # Jersey 15 : un pixel de police = un pixel du jeu
TILE = 1         # StyleBoxTexture : bords et milieu repetes (pas etires)

# nom -> (texture, marges texture g/h/d/b, marges contenu g/h/d/b, options)
BOXES = {
    "Panel": ("panel", (14, 14, 16, 16), (16, 12, 18, 14), {}),
    "HudPanel": ("hud", (18, 10, 10, 8), (9, 8, 10, 7), {}),
    "Toast": ("toast", (18, 10, 12, 8), (12, 7, 12, 7), {}),
    "ButtonNormal": ("button", (10, 10, 10, 12), (10, 3, 10, 6), {}),
    "ButtonHover": ("button_hover", (10, 10, 10, 12), (10, 3, 10, 6), {}),
    "ButtonPressed": ("button_pressed", (10, 10, 10, 12), (10, 5, 10, 4), {}),
    "ButtonDisabled": ("button_disabled", (10, 10, 10, 12), (10, 3, 10, 6), {}),
    "Focus": ("focus", (6, 6, 6, 6), (0, 0, 0, 0), {"draw_center": "false", "expand_margin_left": "2.0", "expand_margin_top": "2.0", "expand_margin_right": "2.0", "expand_margin_bottom": "2.0"}),
    "KeyBadge": ("key_badge", (6, 6, 6, 8), (4, 0, 4, 2), {}),
    "SliderTrack": ("slider_track", (6, 0, 6, 0), (0, 3, 0, 3), {}),
    "SliderFill": ("slider_fill", (6, 0, 6, 0), (0, 3, 0, 3), {}),
    "WordPaper": ("word", (6, 6, 8, 8), (6, 1, 7, 3), {}),
}
ICONS = {"check_on": "check_on", "check_off": "check_off", "grab": "slider_grab", "grab_hi": "slider_grab_hi"}


def project_theme():
    ext = ['[ext_resource type="FontFile" path="res://assets/fonts/Jersey15.ttf" id="body"]',
           '[ext_resource type="FontFile" path="res://assets/fonts/Jersey10.ttf" id="title"]']
    textures = sorted({b[0] for b in BOXES.values()} | set(ICONS.values()))
    for t in textures:
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/ui/notebook/{t}.png" id="tex_{t}"]')
    subs = []
    for name, (tex, tm, cm, opts) in BOXES.items():
        lines = [f'[sub_resource type="StyleBoxTexture" id="{name}"]',
                 f'texture = ExtResource("tex_{tex}")']
        for side, v in zip(("left", "top", "right", "bottom"), tm):
            lines.append(f"texture_margin_{side} = {float(v)}")
        for side, v in zip(("left", "top", "right", "bottom"), cm):
            lines.append(f"content_margin_{side} = {float(v)}")
        lines += [f"axis_stretch_horizontal = {TILE}", f"axis_stretch_vertical = {TILE}"]
        lines += [f"{k} = {v}" for k, v in opts.items()]
        subs.append("\n".join(lines))
    subs.append('[sub_resource type="StyleBoxEmpty" id="Empty"]')
    res = f"""[resource]
default_font = ExtResource("body")
default_font_size = {BODY_SIZE}
Button/colors/font_color = {INK}
Button/colors/font_hover_color = {INK}
Button/colors/font_focus_color = {INK}
Button/colors/font_pressed_color = {INK}
Button/colors/font_hover_pressed_color = {INK}
Button/colors/font_disabled_color = {INK_SOFT}
Button/constants/outline_size = 0
Button/styles/normal = SubResource("ButtonNormal")
Button/styles/hover = SubResource("ButtonHover")
Button/styles/pressed = SubResource("ButtonPressed")
Button/styles/hover_pressed = SubResource("ButtonPressed")
Button/styles/disabled = SubResource("ButtonDisabled")
Button/styles/focus = SubResource("Focus")
CheckButton/colors/font_color = {INK}
CheckButton/colors/font_hover_color = {INK}
CheckButton/colors/font_focus_color = {INK}
CheckButton/colors/font_pressed_color = {INK}
CheckButton/colors/font_hover_pressed_color = {INK}
CheckButton/icons/checked = ExtResource("tex_check_on")
CheckButton/icons/unchecked = ExtResource("tex_check_off")
CheckButton/icons/checked_disabled = ExtResource("tex_check_on")
CheckButton/icons/unchecked_disabled = ExtResource("tex_check_off")
CheckButton/styles/normal = SubResource("Empty")
CheckButton/styles/hover = SubResource("Empty")
CheckButton/styles/pressed = SubResource("Empty")
CheckButton/styles/hover_pressed = SubResource("Empty")
CheckButton/styles/focus = SubResource("Focus")
HSlider/icons/grabber = ExtResource("tex_slider_grab")
HSlider/icons/grabber_highlight = ExtResource("tex_slider_grab_hi")
HSlider/styles/slider = SubResource("SliderTrack")
HSlider/styles/grabber_area = SubResource("SliderFill")
HSlider/styles/grabber_area_highlight = SubResource("SliderFill")
HSlider/styles/focus = SubResource("Focus")
Label/colors/font_color = {CREAM}
Label/colors/font_outline_color = {INK}
Label/constants/outline_size = 4
PanelContainer/styles/panel = SubResource("Panel")
HudPanel/base_type = &"PanelContainer"
HudPanel/styles/panel = SubResource("HudPanel")
Toast/base_type = &"PanelContainer"
Toast/styles/panel = SubResource("Toast")
KeyBadge/base_type = &"PanelContainer"
KeyBadge/styles/panel = SubResource("KeyBadge")
WordPaper/base_type = &"PanelContainer"
WordPaper/styles/panel = SubResource("WordPaper")
PixelTitle/base_type = &"Label"
PixelTitle/fonts/font = ExtResource("title")
"""
    count = len(ext) + len(subs) + 1
    text = f'[gd_resource type="Theme" load_steps={count} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n" + res
    open(os.path.join(ROOT, "assets", "ui", "theme.tres"), "w", encoding="utf-8", newline="\n").write(text)


def paper_theme():
    text = f"""[gd_resource type="Theme" format=3]

[resource]
Label/colors/font_color = {INK}
Label/colors/font_outline_color = Color(0, 0, 0, 0)
Label/constants/outline_size = 0
RichTextLabel/colors/default_color = {INK}
"""
    open(os.path.join(ROOT, "assets", "ui", "paper_theme.tres"), "w", encoding="utf-8", newline="\n").write(text)


if __name__ == "__main__":
    project_theme()
    paper_theme()
    print("ok")
