# Bouwt GunSystem.rbxmx (Script + LocalScript) zodat je het in Studio kan inladen.
# Gebruik: python build.py
from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "src" / "ServerScriptService" / "GunServer"


def item(class_name, referent, name, source, children=""):
    assert "]]>" not in source
    return (
        f'<Item class="{class_name}" referent="{referent}">'
        f'<Properties><string name="Name">{name}</string>'
        f"<ProtectedString name=\"Source\"><![CDATA[{source}]]></ProtectedString>"
        f"</Properties>{children}</Item>"
    )


client = item("LocalScript", "RBX1", "GunClient", (SRC / "GunClient.client.lua").read_text(encoding="utf-8"))
server = item("Script", "RBX0", "GunServer", (SRC / "init.server.lua").read_text(encoding="utf-8"), client)

xml = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
    f"{server}</roblox>\n"
)
(ROOT / "GunSystem.rbxmx").write_text(xml, encoding="utf-8")
print("GunSystem.rbxmx gemaakt")
