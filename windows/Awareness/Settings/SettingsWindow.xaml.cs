using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Awareness.Models;
using Awareness.Resources;
using Microsoft.Win32;

namespace Awareness.Settings;

/// <summary>
/// WPF settings window for configuring all Awareness preferences.
/// Mirrors the macOS SettingsView with identical sections and controls.
/// Changes are applied immediately to SettingsManager (no save button needed).
/// </summary>
public partial class SettingsWindow : Window
{
    private readonly SettingsManager _settings;
    private bool _isLoading = true; // Prevents event handlers from firing during initial load
    private bool _isDarkMode;

    public SettingsWindow()
    {
        InitializeComponent();
        _settings = SettingsManager.Shared;
        ApplyWarmBackground();
        SetLocalizedHeaders();
        LoadSettingsIntoUI();
        _isLoading = false;
    }

    /// <summary>
    /// Detect Windows dark/light mode and set the warm gradient background accordingly.
    /// </summary>
    private void ApplyWarmBackground()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            if (key?.GetValue("AppsUseLightTheme") is int value)
                _isDarkMode = value == 0;
        }
        catch { /* Default to light */ }
        var isDark = _isDarkMode;

        // Light mode: give ComboBoxes a solid white background so the warm gradient
        // doesn't bleed through and make text unreadable
        if (!isDark)
        {
            var comboLightStyle = new Style(typeof(System.Windows.Controls.ComboBox));
            comboLightStyle.Setters.Add(new Setter(ForegroundProperty, System.Windows.Media.Brushes.Black));
            comboLightStyle.Setters.Add(new Setter(BackgroundProperty, System.Windows.Media.Brushes.White));
            Resources[typeof(System.Windows.Controls.ComboBox)] = comboLightStyle;

            var comboItemLightStyle = new Style(typeof(System.Windows.Controls.ComboBoxItem));
            comboItemLightStyle.Setters.Add(new Setter(ForegroundProperty, System.Windows.Media.Brushes.Black));
            Resources[typeof(System.Windows.Controls.ComboBoxItem)] = comboItemLightStyle;
        }

        if (isDark)
        {
            TopGradientStop.Color = Color.FromRgb(36, 26, 51);     // (0.14, 0.10, 0.20)
            BottomGradientStop.Color = Color.FromRgb(23, 18, 36); // (0.09, 0.07, 0.14)

            // Set all text to light colors for dark background contrast
            var lightBrush = new SolidColorBrush(Color.FromRgb(228, 222, 235)); // cool white
            var dimBrush = new SolidColorBrush(Color.FromRgb(155, 148, 165));   // cool gray
            Resources[SystemColors.WindowTextBrushKey] = lightBrush;
            Resources[SystemColors.ControlTextBrushKey] = lightBrush;
            Foreground = lightBrush;

            // Style GroupBox headers and borders
            var gbStyle = new Style(typeof(GroupBox));
            gbStyle.Setters.Add(new Setter(ForegroundProperty, lightBrush));
            gbStyle.Setters.Add(new Setter(BorderBrushProperty, new SolidColorBrush(Color.FromRgb(52, 42, 66))));
            Resources[typeof(GroupBox)] = gbStyle;

            // Style text controls
            var tbStyle = new Style(typeof(System.Windows.Controls.TextBlock));
            tbStyle.Setters.Add(new Setter(System.Windows.Controls.TextBlock.ForegroundProperty, lightBrush));
            Resources[typeof(System.Windows.Controls.TextBlock)] = tbStyle;

            // Style checkboxes and radio buttons
            var cbStyle = new Style(typeof(System.Windows.Controls.CheckBox));
            cbStyle.Setters.Add(new Setter(ForegroundProperty, lightBrush));
            Resources[typeof(System.Windows.Controls.CheckBox)] = cbStyle;

            var rbStyle = new Style(typeof(System.Windows.Controls.RadioButton));
            rbStyle.Setters.Add(new Setter(ForegroundProperty, lightBrush));
            Resources[typeof(System.Windows.Controls.RadioButton)] = rbStyle;

            // Style ComboBox
            var comboStyle = new Style(typeof(System.Windows.Controls.ComboBox));
            comboStyle.Setters.Add(new Setter(ForegroundProperty, lightBrush));
            comboStyle.Setters.Add(new Setter(BackgroundProperty, new SolidColorBrush(Color.FromRgb(40, 34, 50))));
            Resources[typeof(System.Windows.Controls.ComboBox)] = comboStyle;

            // Style TextBox
            var textBoxStyle = new Style(typeof(System.Windows.Controls.TextBox));
            textBoxStyle.Setters.Add(new Setter(ForegroundProperty, lightBrush));
            textBoxStyle.Setters.Add(new Setter(BackgroundProperty, new SolidColorBrush(Color.FromRgb(40, 34, 50))));
            textBoxStyle.Setters.Add(new Setter(BorderBrushProperty, new SolidColorBrush(Color.FromRgb(52, 42, 66))));
            Resources[typeof(System.Windows.Controls.TextBox)] = textBoxStyle;

            // Style Buttons
            var btnStyle = new Style(typeof(System.Windows.Controls.Button));
            btnStyle.Setters.Add(new Setter(ForegroundProperty, lightBrush));
            btnStyle.Setters.Add(new Setter(BackgroundProperty, new SolidColorBrush(Color.FromRgb(44, 38, 54))));
            btnStyle.Setters.Add(new Setter(BorderBrushProperty, new SolidColorBrush(Color.FromRgb(62, 52, 76))));
            Resources[typeof(System.Windows.Controls.Button)] = btnStyle;
        }
    }

    /// <summary>
    /// Set GroupBox headers with emoji prefixes from localized resource strings.
    /// </summary>
    private void SetLocalizedHeaders()
    {
        ActiveHoursGroup.Header = Strings.ActiveHours;
        DesktopSyncGroup.Header = Strings.DesktopSync;
        IntervalGroup.Header = Strings.IntervalBetweenBlackouts;
        DurationGroup.Header = Strings.BlackoutDuration;
        VisualGroup.Header = Strings.BlackoutVisual;
        SoundGroup.Header = Strings.Sound;
        BehaviorGroup.Header = Strings.Behavior;

        // Desktop Sync localized labels
        WorksOnPhoneCheck.Content = Strings.IAlsoWorkOnComputer;
        SyncKeyLabel.Text = Strings.SyncKeyFromPhone;
        SyncKeyHint.Text = Strings.SyncKeyHint;
    }

    /// <summary>
    /// Populate all UI controls from the current settings values.
    /// </summary>
    private void LoadSettingsIntoUI()
    {
        // Active Hours — populate hour combo boxes
        var comboTextBrush = _isDarkMode
            ? new SolidColorBrush(Color.FromRgb(230, 225, 220))
            : System.Windows.Media.Brushes.Black;
        for (int h = 0; h < 24; h++)
        {
            string label = $"{h:D2}:00";
            StartHourCombo.Items.Add(new ComboBoxItem { Content = label, Tag = h, Foreground = comboTextBrush });
            EndHourCombo.Items.Add(new ComboBoxItem { Content = label, Tag = h, Foreground = comboTextBrush });
        }
        // Override XAML defaults for dark mode; light mode uses XAML White/Black
        if (_isDarkMode)
        {
            var darkBg = new SolidColorBrush(Color.FromRgb(45, 40, 36));
            StartHourCombo.Foreground = comboTextBrush;
            StartHourCombo.Background = darkBg;
            EndHourCombo.Foreground = comboTextBrush;
            EndHourCombo.Background = darkBg;
        }
        StartHourCombo.SelectedIndex = _settings.ActiveStartHour;
        EndHourCombo.SelectedIndex = _settings.ActiveEndHour;

        // Interval Range
        IntervalSlider.LowValue = _settings.MinInterval;
        IntervalSlider.HighValue = _settings.MaxInterval;
        UpdateIntervalLabels();

        // Subscribe to range slider changes via binding workaround
        IntervalSlider.Loaded += (_, _) =>
        {
            // Monitor value changes through the dependency properties
            var lowDesc = System.ComponentModel.DependencyPropertyDescriptor.FromProperty(
                RangeSlider.LowValueProperty, typeof(RangeSlider));
            lowDesc?.AddValueChanged(IntervalSlider, (_, _) =>
            {
                if (_isLoading) return;
                _settings.MinInterval = IntervalSlider.LowValue;
                UpdateIntervalLabels();
            });

            var highDesc = System.ComponentModel.DependencyPropertyDescriptor.FromProperty(
                RangeSlider.HighValueProperty, typeof(RangeSlider));
            highDesc?.AddValueChanged(IntervalSlider, (_, _) =>
            {
                if (_isLoading) return;
                _settings.MaxInterval = IntervalSlider.HighValue;
                UpdateIntervalLabels();
            });
        };

        // Blackout Duration
        DurationSlider.LowValue = _settings.MinBlackoutDuration;
        DurationSlider.HighValue = _settings.MaxBlackoutDuration;
        UpdateDurationLabels();

        // Subscribe to duration range slider changes
        DurationSlider.Loaded += (_, _) =>
        {
            var lowDesc = System.ComponentModel.DependencyPropertyDescriptor.FromProperty(
                RangeSlider.LowValueProperty, typeof(RangeSlider));
            lowDesc?.AddValueChanged(DurationSlider, (_, _) =>
            {
                if (_isLoading) return;
                _settings.MinBlackoutDuration = DurationSlider.LowValue;
                UpdateDurationLabels();
            });

            var highDesc = System.ComponentModel.DependencyPropertyDescriptor.FromProperty(
                RangeSlider.HighValueProperty, typeof(RangeSlider));
            highDesc?.AddValueChanged(DurationSlider, (_, _) =>
            {
                if (_isLoading) return;
                _settings.MaxBlackoutDuration = DurationSlider.HighValue;
                UpdateDurationLabels();
            });
        };

        // Visual Type
        switch (_settings.VisualType)
        {
            case BlackoutVisualType.PlainBlack: RadioPlainBlack.IsChecked = true; break;
            case BlackoutVisualType.Text: RadioText.IsChecked = true; break;
            case BlackoutVisualType.Image: RadioImage.IsChecked = true; break;
            case BlackoutVisualType.Video: RadioVideo.IsChecked = true; break;
            case BlackoutVisualType.CardPhoto: RadioCardPhoto.IsChecked = true; break;
        }
        CustomTextBox.Text = _settings.CustomText;
        UpdateVisualTypeUI();
        UpdateFilePickerLabels();

        // Sound
        StartGongCheck.IsChecked = _settings.StartGongEnabled;
        EndGongCheck.IsChecked = _settings.EndGongEnabled;

        // Behavior
        HandcuffsCheck.IsChecked = _settings.HandcuffsMode;
        StartclickCheck.IsChecked = _settings.StartclickConfirmation;
        SkipMediaCheck.IsChecked = _settings.SkipDuringMediaUse;

        // Daily Card
        foreach (var card in PracticeCard.AllCards)
            ManualCardCombo.Items.Add(new ComboBoxItem { Content = card.LocalizedTitle, Tag = card.Id, Foreground = comboTextBrush });
        if (_isDarkMode)
        {
            ManualCardCombo.Foreground = comboTextBrush;
            ManualCardCombo.Background = new SolidColorBrush(Color.FromRgb(45, 40, 36));
        }
        ManualCardCheck.IsChecked = _settings.ManualCardSelectionEnabled;
        int cardIdx = Array.FindIndex(PracticeCard.AllCards, c => c.Id == _settings.ManualCardID);
        ManualCardCombo.SelectedIndex = cardIdx >= 0 ? cardIdx : 0;
        CardPhotoSyncCheck.IsChecked = _settings.CardPhotoSyncEnabled;
        BuildCardPhotoRows();
        UpdateDailyCardUI();

        // Desktop Sync
        SyncKeyInput.Text = _settings.SyncPassphrase;
        bool hasSyncKey = !string.IsNullOrWhiteSpace(_settings.SyncPassphrase);
        WorksOnPhoneCheck.IsChecked = hasSyncKey;
        SyncKeyPanel.Visibility = hasSyncKey ? Visibility.Visible : Visibility.Collapsed;
    }

    // MARK: - Daily Card

    private void OnManualCardChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.ManualCardSelectionEnabled = ManualCardCheck.IsChecked == true;
        // Make sure a card id is stored when enabling manual selection
        if (_settings.ManualCardSelectionEnabled
            && string.IsNullOrEmpty(_settings.ManualCardID)
            && ManualCardCombo.SelectedItem is ComboBoxItem item)
        {
            _settings.ManualCardID = (string)item.Tag;
        }
        UpdateDailyCardUI();
    }

    private void OnManualCardSelected(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading || ManualCardCombo.SelectedItem is not ComboBoxItem item) return;
        _settings.ManualCardID = (string)item.Tag;
    }

    private void OnPickRandomCard(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        var card = PracticeCard.AllCards[Random.Shared.Next(PracticeCard.AllCards.Length)];
        _settings.ManualCardSelectionEnabled = true;
        _settings.ManualCardID = card.Id;
        _ = Awareness.Sync.CardAssetSync.Shared.PushIfEnabledAsync();
        // Reflect in the UI
        _isLoading = true;
        ManualCardCheck.IsChecked = true;
        int idx = Array.FindIndex(PracticeCard.AllCards, c => c.Id == card.Id);
        if (idx >= 0) ManualCardCombo.SelectedIndex = idx;
        _isLoading = false;
        UpdateDailyCardUI();
    }

    private void UpdateDailyCardUI()
    {
        bool manual = ManualCardCheck.IsChecked == true;
        ManualCardCombo.Visibility = manual ? Visibility.Visible : Visibility.Collapsed;
        DailyCardHint.Text = manual ? Strings.DailyCardManualHint : Strings.DailyCardRotationHint;
    }

    private void OnCardPhotoSyncChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.CardPhotoSyncEnabled = CardPhotoSyncCheck.IsChecked == true;
    }

    private Brush ComboTextBrush() => _isDarkMode
        ? new SolidColorBrush(Color.FromRgb(230, 225, 220))
        : System.Windows.Media.Brushes.Black;

    /// <summary>Build one row per card with front/back photo buttons (rebuilt on change).</summary>
    private void BuildCardPhotoRows()
    {
        CardPhotoPanel.Children.Clear();
        var textBrush = ComboTextBrush();

        foreach (var card in PracticeCard.AllCards)
        {
            var row = new DockPanel { Margin = new Thickness(0, 2, 0, 2) };

            var backBtn = MakePhotoButton(card, CardPhotoSide.Back);
            DockPanel.SetDock(backBtn, Dock.Right);
            var frontBtn = MakePhotoButton(card, CardPhotoSide.Front);
            DockPanel.SetDock(frontBtn, Dock.Right);

            var title = new TextBlock
            {
                Text = card.LocalizedTitle,
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = textBrush,
                TextTrimming = TextTrimming.CharacterEllipsis
            };

            row.Children.Add(backBtn);
            row.Children.Add(frontBtn);
            row.Children.Add(title);
            CardPhotoPanel.Children.Add(row);
        }
    }

    private Button MakePhotoButton(PracticeCard card, CardPhotoSide side)
    {
        bool has = _settings.HasCardPhoto(card.Id, side);
        string label = side == CardPhotoSide.Front ? Strings.PhotoFront : Strings.PhotoBack;
        var btn = new Button
        {
            Content = has ? $"✓ {label}" : label,
            Margin = new Thickness(6, 0, 0, 0),
            Padding = new Thickness(8, 2, 8, 2),
            Tag = (card, side)
        };
        btn.Click += OnCardPhotoButtonClick;

        if (has)
        {
            var menu = new ContextMenu();
            var remove = new MenuItem { Header = Strings.RemovePhoto };
            remove.Click += (_, _) =>
            {
                _settings.ClearCardPhoto(card.Id, side);
                _ = Awareness.Sync.CardAssetSync.Shared.PushIfEnabledAsync();
                BuildCardPhotoRows();
            };
            menu.Items.Add(remove);
            btn.ContextMenu = menu;
        }
        return btn;
    }

    private void OnCardPhotoButtonClick(object sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not (PracticeCard card, CardPhotoSide side)) return;

        var dialog = new OpenFileDialog
        {
            Filter = "Image Files|*.png;*.jpg;*.jpeg;*.bmp;*.tiff;*.gif|All Files|*.*",
            Title = card.LocalizedTitle
        };
        if (dialog.ShowDialog() == true)
        {
            _settings.ImportCardPhoto(card.Id, side, dialog.FileName);
            _ = Awareness.Sync.CardAssetSync.Shared.PushIfEnabledAsync();
            BuildCardPhotoRows();
        }
    }

    // MARK: - Active Hours

    private void OnStartHourChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading || StartHourCombo.SelectedItem is not ComboBoxItem item) return;
        _settings.ActiveStartHour = (int)item.Tag;
    }

    private void OnEndHourChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading || EndHourCombo.SelectedItem is not ComboBoxItem item) return;
        _settings.ActiveEndHour = (int)item.Tag;
    }

    // MARK: - Interval

    private void UpdateIntervalLabels()
    {
        MinIntervalLabel.Text = $"{(int)IntervalSlider.LowValue} min";
        MaxIntervalLabel.Text = $"{(int)IntervalSlider.HighValue} min";
    }

    // MARK: - Duration

    private void UpdateDurationLabels()
    {
        if (MinDurationLabel != null)
            MinDurationLabel.Text = $"{(int)DurationSlider.LowValue}s";
        if (MaxDurationLabel != null)
            MaxDurationLabel.Text = $"{(int)DurationSlider.HighValue}s";
    }

    // MARK: - Visual Type

    private void OnVisualTypeChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;

        if (RadioPlainBlack.IsChecked == true) _settings.VisualType = BlackoutVisualType.PlainBlack;
        else if (RadioText.IsChecked == true) _settings.VisualType = BlackoutVisualType.Text;
        else if (RadioImage.IsChecked == true) _settings.VisualType = BlackoutVisualType.Image;
        else if (RadioVideo.IsChecked == true) _settings.VisualType = BlackoutVisualType.Video;
        else if (RadioCardPhoto.IsChecked == true) _settings.VisualType = BlackoutVisualType.CardPhoto;

        UpdateVisualTypeUI();
    }

    private void UpdateVisualTypeUI()
    {
        TextPanel.Visibility = RadioText.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        ImagePanel.Visibility = RadioImage.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        VideoPanel.Visibility = RadioVideo.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnCustomTextChanged(object sender, TextChangedEventArgs e)
    {
        if (_isLoading) return;
        _settings.CustomText = CustomTextBox.Text;
    }

    // MARK: - File Pickers

    private void OnChooseImage(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Image Files|*.png;*.jpg;*.jpeg;*.bmp;*.tiff;*.gif|All Files|*.*",
            Title = Strings.BlackoutVisual
        };

        if (dialog.ShowDialog() == true)
        {
            _settings.CustomImagePath = dialog.FileName;
            UpdateFilePickerLabels();
        }
    }

    private void OnClearImage(object sender, RoutedEventArgs e)
    {
        _settings.CustomImagePath = "";
        UpdateFilePickerLabels();
    }

    private void OnChooseVideo(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Video Files|*.mp4;*.avi;*.wmv;*.mov;*.mkv|All Files|*.*",
            Title = Strings.BlackoutVisual
        };

        if (dialog.ShowDialog() == true)
        {
            _settings.CustomVideoPath = dialog.FileName;
            UpdateFilePickerLabels();
        }
    }

    private void OnClearVideo(object sender, RoutedEventArgs e)
    {
        _settings.CustomVideoPath = "";
        UpdateFilePickerLabels();
    }

    private void UpdateFilePickerLabels()
    {
        // Image path
        if (string.IsNullOrEmpty(_settings.CustomImagePath))
        {
            ImagePathLabel.Text = Strings.Default;
            ClearImageButton.Visibility = Visibility.Collapsed;
        }
        else
        {
            ImagePathLabel.Text = System.IO.Path.GetFileName(_settings.CustomImagePath);
            ClearImageButton.Visibility = Visibility.Visible;
        }

        // Video path
        if (string.IsNullOrEmpty(_settings.CustomVideoPath))
        {
            VideoPathLabel.Text = Strings.NoneLabel;
            ClearVideoButton.Visibility = Visibility.Collapsed;
        }
        else
        {
            VideoPathLabel.Text = System.IO.Path.GetFileName(_settings.CustomVideoPath);
            ClearVideoButton.Visibility = Visibility.Visible;
        }
    }

    // MARK: - Sound

    private void OnStartGongChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.StartGongEnabled = StartGongCheck.IsChecked == true;
    }

    private void OnEndGongChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.EndGongEnabled = EndGongCheck.IsChecked == true;
    }

    // MARK: - Behavior

    private void OnHandcuffsChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.HandcuffsMode = HandcuffsCheck.IsChecked == true;
    }

    private void OnStartclickChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.StartclickConfirmation = StartclickCheck.IsChecked == true;
    }

    private void OnSkipMediaChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        _settings.SkipDuringMediaUse = SkipMediaCheck.IsChecked == true;
    }

    // MARK: - Desktop Sync

    private void OnWorksOnPhoneChanged(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        bool expanded = WorksOnPhoneCheck.IsChecked == true;
        SyncKeyPanel.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnSyncKeyChanged(object sender, TextChangedEventArgs e)
    {
        if (_isLoading) return;
        _settings.SyncPassphrase = SyncKeyInput.Text.Trim();
    }
}
