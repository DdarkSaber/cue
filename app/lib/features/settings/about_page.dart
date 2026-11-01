part of 'settings_screen.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _Detail(
      title: 'About Cue',
      children: [
        const Text(
          'Cue: your next story. A free, non-commercial app for deciding what to watch or read next. Name and icon are proposals, not trademark-cleared.',
          style: _body,
        ),
        const CueSectionLabel('Credits'),
        const Text(
          'Anime, manga, manhwa and manhua data and artwork from AniList.\n'
          'Movie titles, ratings and posters from Stremio Cinemeta (an unofficial source).\n'
          'Show artwork and details from TVmaze, used under CC BY-SA.\n'
          'DM Sans by Colophon Foundry, under the SIL Open Font License.',
          style: _body,
        ),
        const CueSectionLabel('How recommendations work'),
        const Text(
          'Rules, not a black box: hard filters first (things you hid, saw or saved never reappear), then a score from tags you rated well, the mood you picked, catalog quality, freshness and a little exploration. Moods are fixed tag sets; your taste comes from your own ratings and swipes. Each reason line states a real signal.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: CueSecondaryButton(
            label: 'Open-source licences',
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Cue',
              applicationLegalese: 'Free and non-commercial.',
            ),
          ),
        ),
      ],
    );
  }
}
