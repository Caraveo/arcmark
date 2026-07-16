from pathlib import Path
import unittest

from arcmark import ArcMarkDiagram, ArcMarkError, STANDARD_VERSION


ROOT = Path(__file__).resolve().parents[3]


class ArcMarkDiagramTests(unittest.TestCase):
    def test_reads_the_checked_in_commerce_example(self) -> None:
        diagram = ArcMarkDiagram.from_file(ROOT / "examples" / "commerce.arc")

        self.assertEqual(diagram.title, "Commerce Domain")
        self.assertEqual(diagram.version, STANDARD_VERSION)
        self.assertEqual(diagram.owner, "Commerce Team")
        self.assertEqual(diagram.creator_id, "u_jon")
        self.assertEqual(len(diagram.nodes), 5)
        self.assertEqual(len(diagram.relationships), 5)

    def test_parses_owner_and_creator_id_attributes(self) -> None:
        document = """
        <arcmark version="1.1.0">
          <diagram title="Owned" owner="Retail Apps" creator-id="u_jon">
            <nodes><node id="a" name="A" kind="entity" x="0" y="0"/></nodes>
            <relationships/>
          </diagram>
        </arcmark>
        """
        diagram = ArcMarkDiagram.from_xml(document)
        self.assertEqual(diagram.owner, "Retail Apps")
        self.assertEqual(diagram.creator_id, "u_jon")

    def test_accepts_a_v1_0_0_document(self) -> None:
        document = """
        <arcmark version="1.0.0">
          <diagram title="Legacy">
            <nodes><node id="a" name="A" kind="entity" x="0" y="0"/></nodes>
            <relationships/>
          </diagram>
        </arcmark>
        """
        diagram = ArcMarkDiagram.from_xml(document)
        self.assertEqual(diagram.version, "1.0.0")
        self.assertIsNone(diagram.owner)
        self.assertIsNone(diagram.creator_id)

    def test_rejects_an_unsupported_standard_version(self) -> None:
        document = """
        <arcmark version="2.0.0">
          <diagram title="Future">
            <nodes><node id="a" name="A" kind="entity" x="0" y="0"/></nodes>
            <relationships/>
          </diagram>
        </arcmark>
        """
        with self.assertRaisesRegex(ArcMarkError, "Unsupported ArcMark version"):
            ArcMarkDiagram.from_xml(document)

    def test_rejects_a_relationship_to_a_missing_node(self) -> None:
        document = """
        <arcmark version="1.0.0">
          <diagram title="Broken">
            <nodes><node id="a" name="A" kind="entity" x="0" y="0"/></nodes>
            <relationships><relationship from="a" to="missing" type="calls"/></relationships>
          </diagram>
        </arcmark>
        """
        with self.assertRaisesRegex(ArcMarkError, "unknown node"):
            ArcMarkDiagram.from_xml(document)


if __name__ == "__main__":
    unittest.main()
