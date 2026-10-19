import QtQuick

// The product picture of Solar Now: a panel under a rising sun, with a bolt for the energy it makes.
Canvas {
    width: 512
    height: 512

    // A sunrise: the colours of the sky, the panel, the sun and the bolt.
    readonly property var look: ({ top: "#3b2a8a", bottom: "#ff8a4c", panelTop: "#1d2b6e", panelBottom: "#0c1440", grid: "#8fa6ff", frame: "#fff1e6", sun: ["#fff3c4", "#ffc145", "#ff7a1a"], glow: "rgba(255, 170, 70, 0.6)", bolt: "#ffd23f" })

    /**
     * 0…1 along the loop of the animated picture; 0 is the still one. The rays turn by one ray, the
     * glow breathes, a light runs over the panel and the bolt flares when it passes.
     */
    property real phase: 0
    readonly property real wave: Math.cos(2 * Math.PI * phase)
    /** Where the light over the panel is: off it before 0.1 and after 0.6. */
    readonly property real sweep: (phase - 0.1) / 0.5
    readonly property real flare: Math.max(0, 1 - Math.abs(phase - 0.42) / 0.1)

    onPhaseChanged: requestPaint()

    function lerp(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]; }

    onPaint: {
        const c = getContext("2d");
        c.reset();

        // The rounded square.
        c.beginPath();
        c.roundedRect(0, 0, width, height, 112, 112);
        const sky = c.createLinearGradient(0, 0, 0, height);
        sky.addColorStop(0, look.top);
        sky.addColorStop(1, look.bottom);
        c.fillStyle = sky;
        c.fill();
        c.save();
        c.clip();

        // The sun and its glow, high on the right, partly behind the panel.
        const glow = c.createRadialGradient(350, 160, 60, 350, 160, 230);
        glow.addColorStop(0, `rgba(255, 170, 70, ${0.48 + 0.12 * wave})`);
        glow.addColorStop(1, "rgba(255, 230, 160, 0)");
        c.fillStyle = glow;
        c.fillRect(0, 0, width, height);
        // Twelve rays, turned by one of them over the loop, so that it starts again unnoticed.
        c.save();
        c.translate(350, 160);
        c.rotate(phase * Math.PI / 6);
        c.fillStyle = "rgba(255, 214, 120, 0.42)";

        for (let ray = 0; ray < 12; ray++) {
            c.rotate(Math.PI / 6);
            c.beginPath();
            c.moveTo(-10, -100); c.lineTo(0, -150); c.lineTo(10, -100); c.closePath();
            c.fill();
        }

        c.restore();

        const sun = c.createRadialGradient(330, 140, 10, 350, 160, 92);
        sun.addColorStop(0, look.sun[0]);
        sun.addColorStop(0.6, look.sun[1]);
        sun.addColorStop(1, look.sun[2]);
        c.beginPath();
        c.arc(350, 160, 88, 0, Math.PI * 2);
        c.fillStyle = sun;
        c.fill();

        // The stand.
        c.fillStyle = look.frame;
        c.globalAlpha = 0.9;
        c.fillRect(244, 380, 22, 70);
        c.fillRect(196, 442, 118, 16);
        c.globalAlpha = 1;

        // The panel, seen from below and to the left: a quadrilateral with a grid of cells.
        const tl = [92, 236], tr = [372, 196], br = [432, 372], bl = [70, 408];
        c.beginPath();
        c.moveTo(tl[0], tl[1]); c.lineTo(tr[0], tr[1]); c.lineTo(br[0], br[1]); c.lineTo(bl[0], bl[1]); c.closePath();
        const face = c.createLinearGradient(0, 196, 0, 408);
        face.addColorStop(0, look.panelTop);
        face.addColorStop(1, look.panelBottom);
        c.fillStyle = face;
        c.fill();
        c.lineJoin = "round";
        c.lineWidth = 12;
        c.strokeStyle = look.frame;
        c.stroke();

        c.lineWidth = 4;
        c.strokeStyle = look.grid;
        for (let i = 1; i < 4; i++) {
            const a = lerp(tl, tr, i / 4), b = lerp(bl, br, i / 4);
            c.beginPath(); c.moveTo(a[0], a[1]); c.lineTo(b[0], b[1]); c.stroke();
        }
        for (let j = 1; j < 3; j++) {
            const a = lerp(tl, bl, j / 3), b = lerp(tr, br, j / 3);
            c.beginPath(); c.moveTo(a[0], a[1]); c.lineTo(b[0], b[1]); c.stroke();
        }

        // A light running over the panel, from left to right.
        if (sweep > 0 && sweep < 1) {
            const x = -200 + 820 * sweep;
            c.save();
            c.beginPath();
            c.moveTo(tl[0], tl[1]); c.lineTo(tr[0], tr[1]); c.lineTo(br[0], br[1]); c.lineTo(bl[0], bl[1]); c.closePath();
            c.clip();
            const light = c.createLinearGradient(x, 0, x + 140, 0);
            light.addColorStop(0, "rgba(255, 255, 255, 0)");
            light.addColorStop(0.5, "rgba(255, 255, 255, 0.28)");
            light.addColorStop(1, "rgba(255, 255, 255, 0)");
            c.fillStyle = light;
            c.fillRect(x, 0, 140, height);
            c.restore();
        }

        // The energy: a bolt on the panel, flaring as the light passes it.
        c.beginPath();
        c.moveTo(262, 238); c.lineTo(212, 318); c.lineTo(250, 318); c.lineTo(232, 384); c.lineTo(296, 290); c.lineTo(258, 290); c.closePath();
        c.save();
        c.shadowColor = "rgba(255, 230, 120, 0.95)";
        c.shadowBlur = 36 * flare;
        c.fillStyle = flare > 0 ? Qt.tint(look.bolt, Qt.rgba(1, 1, 1, 0.6 * flare)) : look.bolt;
        c.fill();
        c.restore();
        c.lineWidth = 6;
        c.strokeStyle = "rgba(0, 0, 0, 0.25)";
        c.stroke();

        c.restore();
    }
}
