using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media.Animation;

namespace Awareness.Blackout;

/// <summary>
/// Post-blackout UserControl that manages the two-phase awareness flow:
///
///   Phase 1 — Awareness Check:
///     "Were you there?" question with a slider (0–100).
///     Saves on slider release. Invokes OnAwarenessAnswered with the score.
///
///   Phase 2 — Practice Card:
///     Card title, thin separator, optional micro-task text, and a
///     "click anywhere to continue" hint.  Invokes OnDismissRequested on
///     any mouse click.
///
/// Usage:
///   1. Create the control and wire up the two callbacks.
///   2. Call ShowAwarenessCheck() to fade in Phase 1.
///   3. After the user releases the slider, call ShowPracticeCard() to cross-fade to Phase 2.
///   4. After OnDismissRequested fires, remove or hide the control.
/// </summary>
public partial class PostBlackoutControl : UserControl
{
    // MARK: - Fade Durations

    /// Duration of the awareness check fade-in (0.3 s, ease-in)
    private static readonly Duration FadeInDuration = new(TimeSpan.FromSeconds(0.3));

    /// Duration of each cross-fade leg during phase transition (0.25 s)
    private static readonly Duration TransitionDuration = new(TimeSpan.FromSeconds(0.25));

    // MARK: - Public API

    /// <summary>
    /// Called when the user releases the awareness slider.
    /// The int parameter is the score (0–100).
    /// Fires before the phase transition to the practice card begins.
    /// </summary>
    public Action<int>? OnAwarenessAnswered { get; set; }

    /// <summary>
    /// Called when the user clicks anywhere while the practice card is visible.
    /// The caller should remove or hide this control in response.
    /// </summary>
    public Action? OnDismissRequested { get; set; }

    /// <summary>
    /// True while the awareness check panel is the active phase (slider is visible
    /// and interactive).  False during transitions and in the practice card phase.
    /// </summary>
    public bool IsInAwarenessPhase { get; private set; }

    // MARK: - Init

    public PostBlackoutControl()
    {
        InitializeComponent();
    }

    // MARK: - Phase Control

    /// <summary>
    /// Fade in the awareness check panel (Phase 1).
    /// Should be called once after the control has been added to the visual tree.
    /// </summary>
    public void ShowAwarenessCheck()
    {
        // Ensure card panel is hidden and awareness panel is in the foreground
        CardPanel.Visibility = Visibility.Collapsed;
        CardPanel.Opacity = 0;

        AwarenessPanel.Visibility = Visibility.Visible;
        AwarenessPanel.Opacity = 0;

        // Reset slider to center
        AwarenessSlider.Value = 50;

        IsInAwarenessPhase = true;

        // Fade the awareness panel in from 0 → 1
        var fadeIn = new DoubleAnimation(0, 1, FadeInDuration)
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseIn }
        };
        AwarenessPanel.BeginAnimation(OpacityProperty, fadeIn);
    }

    /// <summary>
    /// Cross-fade from the awareness check to the practice card (Phase 2).
    /// Fades the awareness panel out, then fades the card panel in.
    /// </summary>
    /// <param name="cardTitle">Title text displayed prominently on the card.</param>
    /// <param name="microTaskText">
    ///   Optional secondary italic text below the separator.
    ///   Pass null or empty to hide the micro-task block entirely.
    /// </param>
    public void ShowPracticeCard(string cardTitle, string? microTaskText)
    {
        // Prevent further slider interaction during the transition
        IsInAwarenessPhase = false;

        // Populate card content before the animation starts to avoid a visible flash
        CardTitleText.Text = cardTitle;

        if (!string.IsNullOrWhiteSpace(microTaskText))
        {
            MicroTaskText.Text = microTaskText;
            MicroTaskText.Visibility = Visibility.Visible;
        }
        else
        {
            MicroTaskText.Visibility = Visibility.Collapsed;
        }

        // Step 1: fade the awareness panel out
        var fadeOut = new DoubleAnimation(1, 0, TransitionDuration)
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };

        fadeOut.Completed += (_, _) =>
        {
            // Step 2: hide the awareness panel and reveal the card panel, then fade it in
            AwarenessPanel.Visibility = Visibility.Collapsed;

            CardPanel.Visibility = Visibility.Visible;
            CardPanel.Opacity = 0;

            var fadeIn = new DoubleAnimation(0, 1, TransitionDuration)
            {
                EasingFunction = new CubicEase { EasingMode = EasingMode.EaseIn }
            };
            CardPanel.BeginAnimation(OpacityProperty, fadeIn);
        };

        AwarenessPanel.BeginAnimation(OpacityProperty, fadeOut);
    }

    // MARK: - Slider Handler

    private void OnSliderDragCompleted(object sender, DragCompletedEventArgs e)
    {
        if (!IsInAwarenessPhase) return;
        int score = (int)AwarenessSlider.Value;
        OnAwarenessAnswered?.Invoke(score);
    }

    // MARK: - Card Dismiss Handler

    private void OnCardClicked(object sender, MouseButtonEventArgs e)
    {
        OnDismissRequested?.Invoke();
    }
}
