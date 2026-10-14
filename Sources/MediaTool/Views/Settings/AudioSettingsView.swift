import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Card(title: "Audio Output", systemImage: "waveform") {
            SettingRow(title: "Format", info: HelpText.audioFormat) {
                UtilityPicker(
                    options: AudioFormat.allCases, selection: $app.audio.format, label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }

            if app.audio.format.isLossy {
                SettingRow(title: "Bitrate", info: HelpText.audioBitrate) {
                    UtilityPicker(
                        options: AudioBitrate.allCases, selection: $app.audio.bitrate, label: { $0.label }
                    )
                    .frame(width: 150, alignment: .leading)
                }
            } else {
                SettingRow(title: "Bitrate") {
                    Text("Lossless")
                        .font(TypeScale.body)
                        .foregroundColor(Palette.onSurfaceVariant)
                }
            }

            Text("Video inputs have their audio track extracted; audio inputs are re-encoded.")
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }

        Card(title: "Processing", systemImage: "dial.medium") {
            SettingRow(title: "Normalize", info: HelpText.normalize) {
                Toggle("Loudness (EBU R128)", isOn: $app.audio.normalize)
                    .font(TypeScale.body)
            }
            SettingRow(title: "Gain", info: HelpText.gain) {
                Toggle("Adjust volume", isOn: $app.audio.gainEnabled)
                    .font(TypeScale.body)
            }
            if app.audio.gainEnabled {
                SettingRow(title: "Amount") {
                    HStack(spacing: 10) {
                        Slider(value: $app.audio.gainDB.snapped(), in: -30...30)
                            .frame(minWidth: 90, maxWidth: 180)
                        ValueTag(
                            text: "\(app.audio.gainDB >= 0 ? "+" : "")\(Int(app.audio.gainDB)) dB",
                            width: 58)
                    }
                }
            }
            SettingRow(title: "Sample rate", info: HelpText.sampleRate) {
                UtilityPicker(
                    options: SampleRate.allCases, selection: $app.audio.sampleRate, label: { $0.label }
                )
                .frame(width: 150, alignment: .leading)
            }
            SettingRow(title: "Channels", info: HelpText.channels) {
                SegmentedControl(
                    options: ChannelLayout.allCases,
                    selection: $app.audio.channels,
                    label: { $0.label })
            }
        }

        SpeedSection(settings: $app.audio.playbackSpeed)

        TrimSection(
            enabled: $app.audio.trimEnabled,
            start: $app.audio.trimStart,
            end: $app.audio.trimEnd)
    }
}
