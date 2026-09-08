param(
	[Parameter(Mandatory = $true)]
	[string]$Path
)

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$stream = [System.IO.File]::OpenRead($resolvedPath)
$reader = [System.IO.BinaryReader]::new($stream)

function Read-AseString {
	param([System.IO.BinaryReader]$BinaryReader)
	$length = $BinaryReader.ReadUInt16()
	if ($length -eq 0) {
		return ""
	}
	return [System.Text.Encoding]::UTF8.GetString($BinaryReader.ReadBytes($length))
}

try {
	$fileSize = $reader.ReadUInt32()
	$magic = $reader.ReadUInt16()
	if ($magic -ne 0xA5E0) {
		throw "Not an Aseprite file: $resolvedPath"
	}

	$frameCount = $reader.ReadUInt16()
	$width = $reader.ReadUInt16()
	$height = $reader.ReadUInt16()
	$depth = $reader.ReadUInt16()
	$flags = $reader.ReadUInt32()
	$legacySpeedMs = $reader.ReadUInt16()
	$reader.BaseStream.Position = 128

	$frameDurations = [System.Collections.Generic.List[int]]::new()
	$layers = [System.Collections.Generic.List[object]]::new()
	$tags = [System.Collections.Generic.List[object]]::new()
	$slices = [System.Collections.Generic.List[object]]::new()

	for ($frameIndex = 0; $frameIndex -lt $frameCount; $frameIndex++) {
		$frameStart = $reader.BaseStream.Position
		$frameBytes = $reader.ReadUInt32()
		$frameMagic = $reader.ReadUInt16()
		if ($frameMagic -ne 0xF1FA) {
			throw "Invalid frame header at frame $frameIndex"
		}
		$oldChunkCount = $reader.ReadUInt16()
		$durationMs = $reader.ReadUInt16()
		$reader.ReadBytes(2) | Out-Null
		$newChunkCount = $reader.ReadUInt32()
		$chunkCount = if ($newChunkCount -eq 0) { $oldChunkCount } else { $newChunkCount }
		$frameDurations.Add($durationMs)

		for ($chunkIndex = 0; $chunkIndex -lt $chunkCount; $chunkIndex++) {
			$chunkStart = $reader.BaseStream.Position
			$chunkSize = $reader.ReadUInt32()
			$chunkType = $reader.ReadUInt16()

			switch ($chunkType) {
				0x2004 {
					$layerFlags = $reader.ReadUInt16()
					$layerType = $reader.ReadUInt16()
					$childLevel = $reader.ReadUInt16()
					$reader.ReadUInt16() | Out-Null
					$reader.ReadUInt16() | Out-Null
					$blendMode = $reader.ReadUInt16()
					$opacity = $reader.ReadByte()
					$reader.ReadBytes(3) | Out-Null
					$name = Read-AseString $reader
					$layers.Add([ordered]@{
						name = $name
						child_level = $childLevel
						type = $layerType
						visible = (($layerFlags -band 1) -ne 0)
						editable = (($layerFlags -band 2) -ne 0)
						blend_mode = $blendMode
						opacity = $opacity
					})
				}
				0x2018 {
					$tagCount = $reader.ReadUInt16()
					$reader.ReadBytes(8) | Out-Null
					for ($tagIndex = 0; $tagIndex -lt $tagCount; $tagIndex++) {
						$fromFrame = $reader.ReadUInt16()
						$toFrame = $reader.ReadUInt16()
						$direction = $reader.ReadByte()
						$repeat = $reader.ReadUInt16()
						$reader.ReadBytes(6) | Out-Null
						$color = @($reader.ReadByte(), $reader.ReadByte(), $reader.ReadByte())
						$reader.ReadByte() | Out-Null
						$name = Read-AseString $reader
						$tags.Add([ordered]@{
							name = $name
							from = $fromFrame
							to = $toFrame
							direction = @("forward", "reverse", "ping_pong", "ping_pong_reverse")[$direction]
							repeat = $repeat
							color = $color
							durations_ms = @($frameDurations[$fromFrame..$toFrame])
						})
					}
				}
				0x2022 {
					$keyCount = $reader.ReadUInt32()
					$sliceFlags = $reader.ReadUInt32()
					$reader.ReadUInt32() | Out-Null
					$name = Read-AseString $reader
					$keys = [System.Collections.Generic.List[object]]::new()
					for ($keyIndex = 0; $keyIndex -lt $keyCount; $keyIndex++) {
						$key = [ordered]@{
							frame = $reader.ReadUInt32()
							x = $reader.ReadInt32()
							y = $reader.ReadInt32()
							width = $reader.ReadUInt32()
							height = $reader.ReadUInt32()
						}
						if (($sliceFlags -band 1) -ne 0) {
							$key.center = [ordered]@{
								x = $reader.ReadInt32()
								y = $reader.ReadInt32()
								width = $reader.ReadUInt32()
								height = $reader.ReadUInt32()
							}
						}
						if (($sliceFlags -band 2) -ne 0) {
							$key.pivot = [ordered]@{
								x = $reader.ReadInt32()
								y = $reader.ReadInt32()
							}
						}
						$keys.Add($key)
					}
					$slices.Add([ordered]@{ name = $name; flags = $sliceFlags; keys = $keys })
				}
			}

			$reader.BaseStream.Position = $chunkStart + $chunkSize
		}

		$reader.BaseStream.Position = $frameStart + $frameBytes
	}

	foreach ($tag in $tags) {
		$tag.durations_ms = @($frameDurations[$tag.from..$tag.to])
	}

	[ordered]@{
		path = $resolvedPath
		file_size = $fileSize
		canvas = [ordered]@{ width = $width; height = $height; depth = $depth }
		frame_count = $frameCount
		legacy_speed_ms = $legacySpeedMs
		flags = $flags
		frame_durations_ms = $frameDurations
		layers = $layers
		tags = $tags
		slices = $slices
	} | ConvertTo-Json -Depth 10
}
finally {
	$reader.Dispose()
	$stream.Dispose()
}
