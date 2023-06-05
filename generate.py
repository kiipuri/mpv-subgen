import math
import os
from datetime import timedelta

import ffmpeg
import srt
import whisper_timestamped
from pydub import AudioSegment


def cut_audio(file, audio_track, start_seconds, end_seconds):
    input = ffmpeg.input(file)
    out_filename = "/tmp/out.mkv"
    out = ffmpeg.output(input, out_filename, map=f"0:a:{audio_track}", acodec="copy")
    ffmpeg.run(out, overwrite_output=True)

    sound = AudioSegment.from_file(out_filename)

    StrtTime = float(start_seconds) * 1000
    EndTime = float(end_seconds) * 1000
    extract = sound[StrtTime:EndTime]

    output = "/tmp/tmp.mp3"
    extract.export(output, format="mp3")

    return output


def run_whisper(whisper_model, audio_file):
    # More accurate but slower transcription
    # result = whisper_timestamped.transcribe(
    #     whisper_model,
    #     audio_file,
    #     language=args.language,
    #     vad=True,
    #     detect_disfluencies=True,
    #     beam_size=5,
    #     best_of=5,
    #     temperature=(0.0, 0.2, 0.4, 0.6, 0.8, 1.0),
    # )

    result = whisper_timestamped.transcribe(
        whisper_model,
        audio_file,
        vad=True,
        detect_disfluencies=True,
    )

    os.remove(audio_file)
    return result


def get_cut_subtitles(transcription, start_time):
    lines_cut = []
    for i, line in enumerate(transcription["segments"]):
        sub = srt.Subtitle(
            index=i,
            start=timedelta(seconds=line["start"]),
            end=timedelta(seconds=line["end"]),
            content=line["text"],
        )
        lines_cut.append(sub)

    lines_cut_retimed = []
    for line in list(lines_cut):
        line.start += timedelta(seconds=start_time)
        line.end += timedelta(seconds=start_time)
        lines_cut_retimed.append(line)

    return lines_cut_retimed


def merge_subtitles(orig_subtitles, cut_subtitles, start_time, end_time):
    with open(orig_subtitles, "r") as orig:
        orig_removed_dup = []
        for line in srt.parse(orig.read()):
            if (
                line.start >= timedelta(seconds=start_time)
                and line.start <= timedelta(seconds=end_time)
            ) or (
                line.end >= timedelta(seconds=start_time)
                and line.end <= timedelta(seconds=end_time)
            ):
                continue

            orig_removed_dup.append(line)

        subs = orig_removed_dup + cut_subtitles
        subs = srt.sort_and_reindex(subs)
        subs = srt.compose(subs)

    with open(orig_subtitles, "w") as orig:
        orig.write(subs)


def main(model, args):
    start_time = math.floor(float(args["start"]))
    end_time = start_time + 60 if "end" not in args else math.ceil(float(args["end"]))
    video_file = args["video"]
    audio_track = args["audio"]

    audio_file = cut_audio(video_file, audio_track, start_time, end_time)
    transcription = run_whisper(model, audio_file)
    cut_subtitles = get_cut_subtitles(transcription, start_time)
    merge_subtitles(args["subtitles"], cut_subtitles, start_time, end_time)
