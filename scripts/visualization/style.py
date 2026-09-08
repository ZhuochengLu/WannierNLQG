from __future__ import annotations

import math
import shutil
import subprocess
from typing import Any

import matplotlib as mpl
import matplotlib.font_manager as fm

from .common import VisualizationError, merge_known


STYLE_DEFAULTS: dict[str, Any] = {
    "font_family": "Times New Roman",
    "latex": True,
    "font_size": 12.0,
    "axis_font_size": 14.0,
    "title_font_size": 14.0,
    "tick_font_size": 11.0,
    "legend_font_size": 11.0,
    "colorbar_tick_font_size": 11.0,
    "figsize": [6.4, 4.4],
    "dpi": 600,
    "axes_linewidth": 1.1,
    "tick_direction": "in",
    "minor_ticks": False,
    "major_tick_length": 3.5,
    "minor_tick_length": 2.8,
    "tick_width": 1.0,
    "margins": {"left": 0.16, "right": 0.98, "bottom": 0.16, "top": 0.94},
    "subplot_spacing": {"wspace": 0.34, "hspace": 0.34},
    "legend": {
        "location": "best",
        "bbox_to_anchor": None,
        "columns": 1,
        "frame": True,
        "framealpha": 0.9,
        "facecolor": "white",
        "edgecolor": "#808080",
    },
}


def resolve_style(override: dict[str, Any] | None = None) -> dict[str, Any]:
    style = merge_known(STYLE_DEFAULTS, override or {}, "style")
    if not isinstance(style["font_family"], str) or not style["font_family"].strip():
        raise VisualizationError("style.font_family must be a nonempty string")
    if not isinstance(style["latex"], bool):
        raise VisualizationError("style.latex must be boolean")
    if not isinstance(style["figsize"], list) or len(style["figsize"]) != 2:
        raise VisualizationError("style.figsize must contain exactly two numbers")
    width, height = style["figsize"]
    if not all(math.isfinite(float(value)) and float(value) > 0.0 for value in (width, height)):
        raise VisualizationError("style.figsize values must be positive")
    if isinstance(style["dpi"], bool) or not isinstance(style["dpi"], int) or style["dpi"] <= 0:
        raise VisualizationError("style.dpi must be a positive integer")
    positive_fields = (
        "font_size", "axis_font_size", "title_font_size", "tick_font_size",
        "legend_font_size", "colorbar_tick_font_size", "axes_linewidth",
        "major_tick_length", "minor_tick_length", "tick_width",
    )
    for field in positive_fields:
        value = float(style[field])
        if not math.isfinite(value) or value <= 0.0:
            raise VisualizationError(f"style.{field} must be finite and positive")
    if style["tick_direction"] not in {"in", "out", "inout"}:
        raise VisualizationError("style.tick_direction must be in, out, or inout")
    if not isinstance(style["minor_ticks"], bool):
        raise VisualizationError("style.minor_ticks must be boolean")
    margins = {key: float(value) for key, value in style["margins"].items()}
    if not all(math.isfinite(value) and 0.0 <= value <= 1.0 for value in margins.values()):
        raise VisualizationError("style margins must be finite and within [0,1]")
    if not margins["left"] < margins["right"] or not margins["bottom"] < margins["top"]:
        raise VisualizationError("style margins must satisfy left < right and bottom < top")
    spacing = {key: float(value) for key, value in style["subplot_spacing"].items()}
    if not all(math.isfinite(value) and value >= 0.0 for value in spacing.values()):
        raise VisualizationError("style subplot spacing must be finite and nonnegative")
    legend = style["legend"]
    if not isinstance(legend["location"], str) or not legend["location"].strip():
        raise VisualizationError("style.legend.location must be a nonempty string")
    bbox_to_anchor = legend["bbox_to_anchor"]
    if bbox_to_anchor is not None:
        if (
            not isinstance(bbox_to_anchor, list)
            or len(bbox_to_anchor) not in {2, 4}
            or any(
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not math.isfinite(float(value))
                for value in bbox_to_anchor
            )
        ):
            raise VisualizationError(
                "style.legend.bbox_to_anchor must be null or contain two/four finite numbers"
            )
    if isinstance(legend["columns"], bool) or not isinstance(legend["columns"], int) or legend["columns"] <= 0:
        raise VisualizationError("style.legend.columns must be a positive integer")
    if not isinstance(legend["frame"], bool):
        raise VisualizationError("style.legend.frame must be boolean")
    framealpha = float(legend["framealpha"])
    if not math.isfinite(framealpha) or not 0.0 <= framealpha <= 1.0:
        raise VisualizationError("style.legend.framealpha must be within [0,1]")
    return style


def check_environment(style: dict[str, Any]) -> None:
    family = str(style["font_family"])
    try:
        fm.findfont(family, fallback_to_default=False)
    except ValueError as exc:
        raise VisualizationError(f"required font is unavailable: {family}") from exc
    if not style["latex"]:
        return
    pdflatex = shutil.which("pdflatex")
    kpsewhich = shutil.which("kpsewhich")
    if not pdflatex or not kpsewhich:
        raise VisualizationError("LaTeX style requires pdflatex and kpsewhich")
    for package in ("newtxtext.sty", "newtxmath.sty", "bm.sty", "textgreek.sty"):
        result = subprocess.run(
            [kpsewhich, package], capture_output=True, text=True, check=False
        )
        if result.returncode != 0 or not result.stdout.strip():
            raise VisualizationError(f"required LaTeX package is unavailable: {package}")


def apply_style(style: dict[str, Any]) -> None:
    check_environment(style)
    mpl.rcdefaults()
    mpl.rc("text", usetex=bool(style["latex"]))
    mpl.rc("font", family="serif")
    mpl.rc("font", serif=[str(style["font_family"])])
    if style["latex"]:
        mpl.rcParams["text.latex.preamble"] = (
            r"\usepackage{newtxtext,newtxmath}\usepackage{bm}\usepackage{textgreek}"
        )
    mpl.rcParams.update(
        {
            "font.size": float(style["font_size"]),
            "axes.labelsize": float(style["axis_font_size"]),
            "axes.titlesize": float(style["title_font_size"]),
            "xtick.labelsize": float(style["tick_font_size"]),
            "ytick.labelsize": float(style["tick_font_size"]),
            "legend.fontsize": float(style["legend_font_size"]),
            "axes.linewidth": float(style["axes_linewidth"]),
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )


GREEK = {
    "Γ": r"\textGamma",
    "Δ": r"\textDelta",
    "Λ": r"\textLambda",
    "Σ": r"\textSigma",
    "Ω": r"\textOmega",
    "Π": r"\textPi",
    "Θ": r"\textTheta",
    "Φ": r"\textPhi",
    "Ψ": r"\textPsi",
    "α": r"\textalpha",
    "β": r"\textbeta",
    "γ": r"\textgamma",
    "δ": r"\textdelta",
    "λ": r"\textlambda",
    "σ": r"\textsigma",
    "ω": r"\textomega",
    "π": r"\textpi",
    "θ": r"\texttheta",
    "φ": r"\textphi",
    "ψ": r"\textpsi",
}


def tex_text(value: str) -> str:
    escaped: list[str] = []
    for character in str(value):
        if character in GREEK:
            escaped.append(GREEK[character])
        elif character in "_%&#{}":
            escaped.append("\\" + character)
        elif character == "\\":
            escaped.append(r"\textbackslash{}")
        elif character == "−":
            escaped.append("-")
        else:
            escaped.append(character)
    return r"\textnormal{" + "".join(escaped) + "}"


def style_axes(axis: Any, style: dict[str, Any]) -> None:
    axis.tick_params(
        which="both",
        direction=style["tick_direction"],
        top=True,
        right=True,
        width=float(style["tick_width"]),
    )
    axis.tick_params(which="major", length=float(style["major_tick_length"]))
    if bool(style["minor_ticks"]):
        axis.minorticks_on()
        axis.tick_params(which="minor", length=float(style["minor_tick_length"]))
    else:
        axis.minorticks_off()
    for spine in axis.spines.values():
        spine.set_linewidth(float(style["axes_linewidth"]))


def apply_margins(figure: Any, style: dict[str, Any]) -> None:
    figure.subplots_adjust(
        **{key: float(value) for key, value in style["margins"].items()},
        **{key: float(value) for key, value in style["subplot_spacing"].items()},
    )
