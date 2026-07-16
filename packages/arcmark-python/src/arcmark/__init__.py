"""ArcMark `.arc` document support for Python."""

from .diagram import ArcMarkDiagram, ArcMarkError, ArcMarkField, ArcMarkNode, ArcMarkRelationship, STANDARD_VERSION

__all__ = ["ArcMarkDiagram", "ArcMarkError", "ArcMarkField", "ArcMarkNode", "ArcMarkRelationship", "STANDARD_VERSION"]
__version__ = "1.0.1"
