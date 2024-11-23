package com.pakelcomedy.qleon.ui.splash

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.fragment.app.Fragment
import android.view.View
import androidx.navigation.fragment.findNavController
import com.pakelcomedy.qleon.R

class SplashFragment : Fragment(R.layout.fragment_splash) {

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Add a delay to show splash screen for 0.2 seconds before navigating
        Handler(Looper.getMainLooper()).postDelayed({
            // Navigate to the next fragment (e.g., HomeFragment or LoginFragment)
            findNavController().navigate(R.id.action_splashFragment_to_homeFragment)
        }, 200) // Delay for 0.2 seconds (200 milliseconds)
    }
}