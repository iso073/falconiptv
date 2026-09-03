part of 'epg_cubit.dart';

sealed class EpgState {
  const EpgState();
}

class EpgInitial extends EpgState {
  const EpgInitial();
}

class EpgLoading extends EpgState {
  const EpgLoading();
}

class EpgLoaded extends EpgState {
  const EpgLoaded({
    required this.listings,
    required this.channels,
    required this.selectedChannel,
  });

  final List<EpgListing> listings;
  final List<String> channels;
  final String selectedChannel;

  List<EpgListing> get visibleListings {
    if (selectedChannel == 'Tümü') {
      return listings;
    }
    return listings
        .where((EpgListing listing) => listing.channelName == selectedChannel)
        .toList();
  }

  EpgLoaded copyWith({String? selectedChannel}) {
    return EpgLoaded(
      listings: listings,
      channels: channels,
      selectedChannel: selectedChannel ?? this.selectedChannel,
    );
  }
}

class EpgError extends EpgState {
  const EpgError(this.message);

  final String message;
}
