import {Config} from '@remotion/cli/config';

// The entry point lives in `src/`, so Remotion would otherwise look for the public
// folder at `src/public`. The stills are in `demo/public`.
Config.setPublicDir('public');

// Frames are JPEG (fast, small) at high quality — the stills themselves are JPEGs.
Config.setVideoImageFormat('jpeg');
Config.setJpegQuality(95);

Config.setCodec('h264');
Config.setPixelFormat('yuv420p');
Config.setOverwriteOutput(true);
